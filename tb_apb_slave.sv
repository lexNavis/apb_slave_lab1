module TB;

	logic pclk;
	logic presetn;
	logic psel;
	logic penable;
	logic pwrite;
	logic [31:0] paddr;
	logic [31:0] pwdata;
	wire [31:0] prdata;
	wire pready;
	wire pslverr;

	parameter p_device_offset = 32'h7000_0000;

	logic [31:0] address;
	logic [31:0] data_to_device;
	logic [31:0] data_from_device;


	apb_slave DUT
	(
		.pclk(pclk), //синхросигнал
		.presetn, //сигнал сброса (инверсный)
		.paddr(paddr), //адрес обращения
		.pwdata(pwdata), //данные для записи
		.psel(psel), // признак выбора устройсва
		.penable(penable), //признак активной транзакции
		.pwrite(pwrite), // признак операции записи
		.pready(pready), // признак готовности от устройства
		.pslverr(pslverr), // опциональный сигнал: признак ошибки при обращении
		.prdata(prdata) // прочитанные данные
	);



	task perform_rw(input [31:0] offset, [31:0] data);
		address = p_device_offset+offset;
		data_to_device = data;
		apb_write(address, data_to_device);
		apb_read(address, data_from_device);
		$display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);
	endtask

	task read_pi_real();
		logic [31:0] lo, hi;
		perform_rw(32'h0, 32'h0);   // ctrl[1]=0 → lo
		lo = data_from_device;
		perform_rw(32'h0, 32'h2);   // ctrl[1]=1 → hi
		hi = data_from_device;
		$display("pi = %.15f (hi=0x%h, lo=0x%h)", $bitstoreal({hi, lo}), hi, lo);
	endtask

	task read_e_real();
		logic [31:0] lo, hi;
		perform_rw(32'h0, 32'h1);   // ctrl[0]=1 (e), ctrl[1]=0 → lo
		lo = data_from_device;
		perform_rw(32'h0, 32'h3);   // ctrl[0]=1 (e), ctrl[1]=1 → hi
		hi = data_from_device;
		$display("e = %.15f (hi=0x%h, lo=0x%h)", $bitstoreal({hi, lo}), hi, lo);
	endtask

	task apb_write(input [31:0] addr, [31:0] data);
		wait ((penable==0) && (pready == 0));
		@(posedge pclk);
		psel <= 1'b1;
		paddr[31:0] <= addr[31:0];
		pwdata[31:0] <= data[31:0];
		pwrite <= 1'b1;
		@(posedge pclk);
		penable <= 1'b1;
		@(posedge pclk);
		wait (pready == 1'b1);
		@(posedge pclk);
		psel <= 1'b0;
		penable <= 1'b0;
		pwrite <= 1'b0;
		@(posedge pclk);
	endtask

	task apb_read(input [31:0] addr, output logic [31:0] data);
		wait ((penable==0) && (pready == 0));
		@(posedge pclk);
		psel <= 1'b1;
		pwrite <= 1'b0;
		paddr[31:0] <= addr[31:0];
		@(posedge pclk);
		penable <= 1'b1;
		@(posedge pclk);
		wait (pready == 1'b1);
		/* Данные готовы.
		 * Неблокирующее присвоение обеспечивает 
		 * немедленное считывание данных с регистра */
		data[31:0] = prdata[31:0];
		@(posedge pclk);
		psel <= 1'b0;
		penable <= 1'b0;
		@(posedge pclk);
	endtask

	always
	#10ns pclk=~pclk;

	initial
	begin
		pclk=0;
		presetn=1'b1;
		psel='0;
		penable='0;
		pwrite='0;
		paddr='0;
		pwdata='0;
		repeat (5) @(posedge pclk);
		presetn=1'b0;
		repeat (5) @(posedge pclk);
		presetn=1'b1;
		repeat (5) @(posedge pclk);
		read_pi_real();
		repeat (5) @(posedge pclk);
		read_e_real();
		repeat (10) @(posedge pclk);
		$stop();
	end


	initial
	begin
	$monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h", penable, pready, paddr, pwdata, prdata);
	end
endmodule
