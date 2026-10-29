module TB;

    logic pclk, presetn, psel, penable, pwrite;
    logic [31:0] paddr, pwdata;
    wire  [31:0] prdata;
    wire         pready, pslverr;

    parameter p_device_offset = 32'h7000_0000;

    localparam logic [63:0] PI_REF = 64'h4009_21FB_5444_2D18;
    localparam logic [63:0] E_REF  = 64'h4005_BF0A_8B14_5769;

    int errors = 0;

    apb_slave DUT (
        .pclk(pclk), .presetn(presetn),
        .paddr(paddr), .pwdata(pwdata),
        .psel(psel), .penable(penable), .pwrite(pwrite),
        .pready(pready), .pslverr(pslverr), .prdata(prdata)
    );

    // Запись
    task apb_write(input [31:0] addr, input [31:0] data, output logic err);
        @(posedge pclk);
        psel <= 1; paddr <= addr; pwdata <= data; pwrite <= 1;
        @(posedge pclk);
        penable <= 1;
        @(posedge pclk);
        #1;
        while (pready !== 1'b1) begin
            @(posedge pclk); #1;
        end
        err = pslverr;
        psel <= 0; penable <= 0; pwrite <= 0;
        @(posedge pclk);
    endtask

    // Чтение
    task apb_read(input [31:0] addr, output logic [31:0] data, output logic err);
        @(posedge pclk);
        psel <= 1; pwrite <= 0; paddr <= addr;
        @(posedge pclk);
        penable <= 1;
        @(posedge pclk);
        #1;
        while (pready !== 1'b1) begin
            @(posedge pclk); #1;
        end
        data = prdata;
        err  = pslverr;
        psel <= 0; penable <= 0;
        @(posedge pclk);
    endtask

    // Проверка числа Пи
    task check_pi();
        logic [31:0] lo, hi; logic [63:0] val; logic err;
        apb_write(p_device_offset+32'h0, 32'h0, err); // ctrl=00 -> pi_lo
        apb_read (p_device_offset+32'h0, lo, err);
        apb_write(p_device_offset+32'h0, 32'h2, err); // ctrl=10 -> pi_hi
        apb_read (p_device_offset+32'h0, hi, err);
        val = {hi, lo};
        if (val !== PI_REF) begin
            $error("[PI] mismatch: got 0x%h, exp 0x%h", val, PI_REF); errors++;
        end else
            $display("[PI] OK: 0x%h (%.15f)", val, $bitstoreal(val));
    endtask

    // Проверка числа e
    task check_e();
        logic [31:0] lo, hi; logic [63:0] val; logic err;
        apb_write(p_device_offset+32'h0, 32'h1, err); // ctrl=01 -> e_lo
        apb_read (p_device_offset+32'h0, lo, err);
        apb_write(p_device_offset+32'h0, 32'h3, err); // ctrl=11 -> e_hi
        apb_read (p_device_offset+32'h0, hi, err);
        val = {hi, lo};
        if (val !== E_REF) begin
            $error("[E] mismatch: got 0x%h, exp 0x%h", val, E_REF); errors++;
        end else
            $display("[E] OK: 0x%h (%.15f)", val, $bitstoreal(val));
    endtask

    // Проверка записи по некорректному адресу
    task check_bad_addr_write();
        logic err;
        apb_write(p_device_offset+32'h4, 32'hDEAD_BEEF, err);
        if (err !== 1'b1) begin
            $error("[BAD_WR] pslverr not asserted on bad addr"); errors++;
        end else
            $display("[BAD_WR] OK: pslverr=1");
        @(posedge pclk); #1;
        if (pslverr !== 1'b0) begin
            $error("[BAD_WR] pslverr not cleared in SETUP"); errors++;
        end
    endtask

    // Проверка чтения по некорректному адресу
    task check_bad_addr_read();
        logic [31:0] d; logic err;
        apb_read(p_device_offset+32'h4, d, err);
        if (err !== 1'b1) begin
            $error("[BAD_RD] pslverr not asserted on bad addr"); errors++;
        end else if (d !== 32'h0) begin
            $error("[BAD_RD] prdata=0x%h on bad addr, exp 0", d); errors++;
        end else
            $display("[BAD_RD] OK: pslverr=1, prdata=0");
        @(posedge pclk); #1;
        if (pslverr !== 1'b0) begin
            $error("[BAD_RD] pslverr not cleared in SETUP"); errors++;
        end
    endtask

    // Проверка что запись мусора в неиспользуемые биты не ломает числа
    task check_ctrl_junk_bits();
        logic [31:0] before_lo, after_lo; logic err;
        apb_write(p_device_offset+32'h0, 32'h0, err);
        apb_read (p_device_offset+32'h0, before_lo, err);
        apb_write(p_device_offset+32'h0, 32'hFFFF_FFFC, err);
        apb_write(p_device_offset+32'h0, 32'h0, err);
        apb_read (p_device_offset+32'h0, after_lo, err);
        if (after_lo !== before_lo) begin
            $error("[CTRL] junk bits changed pi_lo: 0x%h != 0x%h", after_lo, before_lo);
            errors++;
        end else
            $display("[CTRL] OK: junk ignored, pi_lo=0x%h", after_lo);
    endtask

    // Проверка pready на удержание 1 такт
    task check_pready_single_cycle();
        @(posedge pclk);
        psel <= 1; penable <= 0; pwrite <= 0; paddr <= p_device_offset;
        @(posedge pclk);
        penable <= 1;
        do @(posedge pclk); while (!pready);
        @(posedge pclk); #1;
        if (pready !== 1'b0) begin
            $error("[PREADY] not deasserted after ACCESS, pready=%b", pready); errors++;
        end else
            $display("[PREADY] OK: deasserted after ACCESS");
        psel <= 0; penable <= 0;
        @(posedge pclk);
    endtask

    // Проверка сброса во время передачи сигналов
    task check_reset_during_access();
        @(posedge pclk);
        psel <= 1; penable <= 0; pwrite <= 0; paddr <= p_device_offset;
        @(posedge pclk);
        penable <= 1;
        @(posedge pclk);
        // Сброс в ACCESS
        presetn <= 0;
        repeat (2) @(posedge pclk);
        psel <= 0; penable <= 0; pwrite <= 0;
        presetn <= 1;
        repeat (2) @(posedge pclk); #1;
        if (pready !== 1'b0 || pslverr !== 1'b0) begin
            $error("[RESET] after reset pready=%b pslverr=%b", pready, pslverr); errors++;
        end else
            $display("[RESET] OK: pready=0, pslverr=0 after mid-access reset");
        // Проверка, что DUT снова рабочий
        check_pi();
        check_e();
    endtask

    task check_prdata_idle();
        @(posedge pclk); #1;
        if (prdata !== 32'h0) begin
            $error("[IDLE] prdata=0x%h outside transaction", prdata); errors++;
        end else
            $display("[IDLE] OK: prdata=0 in idle");
    endtask

    // Основной сценарий тестирования
    always #10ns pclk = ~pclk;

    initial begin
        pclk = 0; presetn = 1; psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
        repeat (5) @(posedge pclk);
        presetn = 0;
        repeat (5) @(posedge pclk);
        presetn = 1;
        repeat (5) @(posedge pclk);

        check_prdata_idle();
        check_pi();
        check_e();
        check_bad_addr_write();
        check_bad_addr_read();
        check_ctrl_junk_bits();
        check_pready_single_cycle();
        check_reset_during_access();

        if (errors == 0) $display("===== TEST PASSED =====");
        else             $display("===== TEST FAILED: %0d error(s) =====", errors);
        $finish;
    end
endmodule