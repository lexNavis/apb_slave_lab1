module apb_slave
(
	input 				pclk,		//синхросигнал
	input 				presetn,	//сигнал сброса (инверсный)
	input [31:0] 		paddr,		//адрес обращения
	input [31:0] 		pwdata,		//данные для записи
	input 				psel,		// признак выбора устройсва
	input				penable,	//признак активной транзакции
	input 				pwrite,		// признак операции записи
	output logic 		pready,		// признак готовности от устройства
	output logic 		pslverr,	// опциональный сигнал: признак ошибки при обращении
	output logic [31:0] prdata		// прочитанные данные
);
	localparam  logic [31:0] pi_hi	= 32'h400921FB, pi_lo	= 32'h54442D18;
	localparam  logic [31:0] e_hi	= 32'h4005BF0A, e_lo	= 32'h8B145769;
	/* Контрольный регистр
	 * 0й бит - выбор числа
	 * 1й бит - выдать старшую 
	 * или младшую часть 
	 * Обращение по адресу со
	 * смещением 0 */
	logic [31:0] ctrl_reg;
	
	//APB FSM
	enum logic [1:0] {
		APB_SETUP,
		APB_W_ENABLE,
		APB_R_ENABLE
	} apb_st;
	
	always @(posedge pclk)
		if (!presetn)
		begin
			prdata 		<= '0;
			pslverr 	<= 1'b0;
			pready 		<= 1'b0;
			ctrl_reg	<= 32'h0;
			apb_st		<= APB_SETUP;
		end
	else
	begin
		case(apb_st)
		APB_SETUP:
		begin: apb_setup_st
		/* pslverr всегда должен быть
		 * сброшен перед началом новой 
		 * транзакции*/
		pslverr <= 1'b0;
		// clear the prdata and error
		prdata <= '0;
		pready <= 1'b0;

		// Move to ENABLE when the psel is asserted
		if (psel && !penable)
		begin
		if (pwrite == 1'b1)
			begin
			apb_st <= APB_W_ENABLE;
			end
		else
			begin
			apb_st <= APB_R_ENABLE;
			end
		end
		end: apb_setup_st

		APB_W_ENABLE:
		begin: apb_w_en_st
		// decode address and write
		if (psel && penable && pwrite)
			begin
				pready <= 1'b1;
				case (paddr[7:0])
					8'h0: begin
						/* Запись в контрольный регистр */
						ctrl_reg[31:0] <= pwdata[31:0]; 
					end
				default:
					begin
						pslverr <= 1'b1;
					end
				endcase
				apb_st <= APB_SETUP;
			end
		end: apb_w_en_st

		APB_R_ENABLE:
		begin: apb_r_en_st
			if (psel && penable && !pwrite)
			begin
				pready <= 1'b1;
				case (paddr[7:0])
					8'h0: begin
						/* Ветка выбора числа пи */
						if (ctrl_reg[0] == 0)
						begin
							/* Выдача младшей части числа пи */
							if (ctrl_reg[1] == 0) 
							begin
								prdata[31:0] <= pi_lo[31:0];
							end
							else
							begin
								prdata[31:0] <= pi_hi[31:0];
							end
						end
						else
						begin	/* Выдача младшей части числа е */
							if (ctrl_reg[1] == 0) 
							begin
								prdata[31:0] <= e_lo[31:0];
							end
							else
							begin
								prdata[31:0] <= e_hi[31:0];
							end
						end
					end
				default:
					begin
						pslverr <= 1'b1;
					end
				endcase
				apb_st <= APB_SETUP;
			end
		end: apb_r_en_st


		default:
			begin
				pslverr <= 1'b1;
				/* Выход из неопределенного состояния
				 * чтобы не зависнуть в нем навечно. */
				apb_st <= APB_SETUP;
			end
		endcase

	end // закончился блок внутри always

endmodule
