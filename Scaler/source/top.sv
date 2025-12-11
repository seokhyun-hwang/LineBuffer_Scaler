`timescale 1ns / 1ps

module line_buf_ctrl_top (
    input clk,
    input rstn,

    // 외부 입력 (카메라/이전 모듈)
    input       i_vsync,
    input       i_hsync,
    input       i_de,
    input [9:0] i_r_data,
    input [9:0] i_g_data,
    input [9:0] i_b_data,

    // 외부 출력 (다음 모듈)
    output reg       o_vsync,
    output reg       o_hsync,
    output reg       o_de,
    output reg [9:0] o_r_data,
    output reg [9:0] o_g_data,
    output reg [9:0] o_b_data
);

    localparam logic [5:0] VACT = 6'd4;  // total 4 lines
    localparam logic [5:0] HACT = 6'd10;  // 10 pixels per line

    localparam ADDR_WIDTH = 6;  // SRAM은 1 line만 저장. -> 10 pixel (HACT). 넉넉히 6bit
    localparam DATA_WIDTH = 30;  // RGB 10bit씩


    // 내부 연결 wire
    logic w_cs1, w_cs2;
    logic w_we1, w_we2;
    logic [ADDR_WIDTH-1:0] w_addr1, w_addr2;
    logic [DATA_WIDTH-1:0] w_din1, w_din2;
    logic [DATA_WIDTH-1:0] w_dout1, w_dout2;  // SRAM에서 나온 데이터


    line_ctrl U_LINE_CTRL (
        .clk (clk),
        .rstn(rstn),

        // 입력 (TOP -> CTRL 입력)
        .i_de    (i_de),
        .i_r_data(i_r_data),
        .i_g_data(i_g_data),
        .i_b_data(i_b_data),
        .i_vsync (i_vsync),
        .i_hsync (i_hsync),

        // 출력 (CTRL -> TOP 출력)
        .o_r    (o_r_data),
        .o_g    (o_g_data),
        .o_b    (o_b_data),
        .o_vsync(o_vsync),
        .o_hsync(o_hsync),
        .o_de   (o_de),

        // 해상도
        .HACT(HACT),  // 한 line 픽셀 수
        .VACT(VACT),  // 총 line수

        // SRAM1
        .o_cs1  (w_cs1),
        .o_we1  (w_we1),
        .o_addr1(w_addr1),
        .o_din1 (w_din1),
        .i_dout1(w_dout1),

        // SRAM2
        .o_cs2  (w_cs2),
        .o_we2  (w_we2),
        .o_addr2(w_addr2),
        .o_din2 (w_din2),
        .i_dout2(w_dout2)
    );


    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_RAM1 (
        .clk   (clk),
        .i_cs  (w_cs1),
        .i_we  (w_we1),
        .i_addr(w_addr1),
        .i_din (w_din1),
        .o_dout(w_dout1)
    );


    single_port_ram #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) U_RAM2 (
        .clk   (clk),
        .i_cs  (w_cs2),
        .i_we  (w_we2),
        .i_addr(w_addr2),
        .i_din (w_din2),
        .o_dout(w_dout2)
    );

    // assign o_vsync  = i_vsync;
    // assign o_hsync  = i_hsync;
    // assign o_de     = i_de;
    // assign o_r_data = i_r_data;
    // assign o_g_data = i_g_data;
    // assign o_b_data = i_b_data;
endmodule





///////////////////////////////////////////////////////////////////////////////////////////////////
// 좌표 추적 : 현재 픽셀이 어디(몇번째 줄, 몇번째 픽셀)인지 알아야 한다. -> H_CNT, V_CNT
// 핑퐁 제어 : 짝수 줄-> sram1 W, sram2 R / 홀수 줄-> sram1 R, sram2 W 
// SRAM은 주소를 주면 1clk 후에 데이터가 나온다.
// 따라서 controller가 내보내지는 o_de, o_hsync, o_vsync 신호도 1 clk 지연시켜 데이터와 박자를 맞춰야 한다.

// IDLE : 리셋 및 프레임 시작 대기.
// WAIT_DE : h_sync 등 line 사이의 공백 대기.
// ACT_FIRST : (첫 줄) 메모리에 쓰기만 하고 출력은 없음.
// ACT_MIDDLE : (중간 줄) 이전 줄을 읽고(출력), 현재 줄을 씀(저장).
// WAIT_FLUSH : 입력은 다 끝났지만, 메모리에 남은 마지막 한 줄을 뱉기 위해 대기.
// ACT_LAST : (마지막 줄) 입력 i_de가 없어도 스스로 카운터를 돌려 메모리에 남은 데이터를 읽음.
///////////////////////////////////////////////////////////////////////////////////////////////////

module line_ctrl (
    input logic clk,
    input logic rstn,

    // 입력 타이밍 및 데이터
    input logic       i_de,
    input logic [9:0] i_r_data,
    input logic [9:0] i_g_data,
    input logic [9:0] i_b_data,
    input logic       i_vsync,
    input logic       i_hsync,

    // 출력 타이밍 및 데이터
    output logic [9:0] o_r,
    output logic [9:0] o_g,
    output logic [9:0] o_b,
    output logic       o_vsync,
    output logic       o_hsync,
    output logic       o_de,

    // 해상도 정보
    input logic [5:0] HACT,  // 한 line 픽셀 수
    input logic [5:0] VACT,  // 총 line수

    // SRAM1
    output logic        o_cs1,
    output logic        o_we1,
    output logic [ 5:0] o_addr1,
    output logic [29:0] o_din1,
    input  logic [29:0] i_dout1,

    // SRAM2
    output logic        o_cs2,
    output logic        o_we2,
    output logic [ 5:0] o_addr2,
    output logic [29:0] o_din2,
    input  logic [29:0] i_dout2
);

    // 상태 FSM =====================================================================================
    typedef enum logic [2:0] {
        IDLE,        // 초기화
        WAIT_DE,     // line들 사이 - 데이터 입력 대기
        ACT_FIRST,   // 첫 line - 오직 Write
        ACT_MIDDLE,  // 중간 line - Read, Write 동시 수행
        WAIT_FLUSH,  // 입력 종료 후 마지막 line 출력 대기
        ACT_LAST     // 마지막 line 출력 - 오직 Read
    } state_t;

    state_t c_state, n_state;


    // 내부 신호
    logic [5:0] h_cnt;  // 가로 픽셀 카운터 -> SRAM 주소(0~HACT)
    logic [5:0] v_cnt;  // 세로 line 카운터 -> 짝홀 (0~VACT)


    // Edge Detector ==============================================================================
    logic vsync_d, hsync_d, de_d;
    wire de_fall = (!i_de && de_d);  // 한 line 입력 종료 감지
    wire vsync_start = (!i_vsync && vsync_d);  // 프레임 시작 Falling Edge
    wire hsync_start = (!i_hsync && hsync_d);  // 라인 종료 Falling Edge (Active Low)


    // data concatenation
    logic [29:0] din_con;
    assign din_con = {i_r_data, i_g_data, i_b_data};


    // 신호 동기화 및 edge detect =======================================================================
    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            vsync_d <= 1'b1;
            hsync_d <= 1'b1;
            de_d    <= 1'b0;
            c_state<=IDLE;
        end else begin
            vsync_d <= i_vsync;
            hsync_d <= i_hsync;
            de_d    <= i_de;

            if (vsync_start) begin
                c_state <= WAIT_DE;  // VSYNC 들어오면 강제 대기
            end else begin
                c_state <= n_state;
            end
        end
    end


    // State Transfer =============================================================================
    always_comb begin
        n_state = c_state;
        case (c_state)
            IDLE: begin
                if (vsync_start) begin
                    n_state = WAIT_DE;
                end
            end

            WAIT_DE: begin
                if (i_de) begin
                    if (v_cnt == 0) begin  // 첫번째 줄이면 
                        n_state = ACT_FIRST;
                    end else begin  // 첫번째 줄이 아니면
                        n_state = ACT_MIDDLE;
                    end
                end else if (v_cnt == VACT) begin   // 한 회면을 다 받으면 마지막 버퍼 비우기
                    n_state = WAIT_FLUSH;
                end
            end

            ACT_FIRST: begin
                if (de_fall) begin  // 한 줄 쓰기 끝
                    n_state = WAIT_DE;
                end
            end

            ACT_MIDDLE: begin
                if (de_fall) begin  // 한 줄 처리 끝
                    n_state = WAIT_DE;
                end
            end

            WAIT_FLUSH: begin  // 안정적인 타이밍을 위해 다음 HSYNC 기다렸다가 쏨
                if (hsync_start) begin  // 한 line 마치고 다음 line 시작 시
                    n_state = ACT_LAST;
                end
            end

            ACT_LAST: begin  // 입력 de가 없어 h_cnt가 증가하다, h_cnt==HACT가 되면 종료
                if (h_cnt == HACT - 1) begin
                    n_state = IDLE;
                end
            end

            default: n_state = IDLE;
        endcase
    end


    // 카운터 로직 =====================================================================================
    // h_cnt : 입력이 있을 땐 i_de를 따르고, 마지막 줄인 Flush 구간엔 스스로 count.
    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            h_cnt <= 0;
        end else begin
            // if (c_state == ACT_FIRST || c_state == ACT_MIDDLE) begin
            if (n_state == ACT_FIRST || n_state == ACT_MIDDLE) begin
                if (i_de) begin
                    h_cnt <= h_cnt + 1;
                end else begin
                    h_cnt <= 0;
                end
            end  
            else if (c_state == ACT_LAST) begin     // [FLUSH] i_de 상관없이 HACT까지 무조건 증가
                if (h_cnt < HACT) begin
                    h_cnt <= h_cnt + 1;
                end else begin
                    h_cnt <= 0;
                end
            end else begin
                h_cnt <= 0;
            end
        end
    end

    // v_cnt
    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            v_cnt <= 0;
        end else begin
            if (vsync_start) begin  // 프레임 시작 리셋
                v_cnt <= 0;
            end else if (de_fall) begin  // 한 줄 끝날 때마다
                v_cnt <= v_cnt + 1;
            end
        end

    end


    // SRAM 제어 ====================================================================================
    // clk rising edge에서 주소(addr)를 주면 데이터(dout)는 그 다음 clk rising edge 이후에 나옴.(1박자 늦음)
    logic ram_sel;
    assign ram_sel = v_cnt[0];  // 0: Even, 1: Odd

    always_comb begin
        o_cs1   = 0;
        o_we1   = 0;
        o_addr1 = h_cnt;
        o_din1  = din_con;
        o_cs2   = 0;
        o_we2   = 0;
        o_addr2 = h_cnt;
        o_din2  = din_con;

        // case (c_state)
        case (n_state)
            ACT_FIRST: begin  // 첫줄 : Write O, Read X // v_cnt=0(Even)
                o_cs1 = 1;
                o_we1 = 1;
                o_cs2 = 0;
                o_we2 = 0;
            end

            ACT_MIDDLE: begin  // 중간줄 : W / R 동시
                if (ram_sel == 0) begin  // 짝수
                    o_cs1 = 1;
                    o_we1 = 1;  // SRAM1 W
                    o_cs2 = 1;
                    o_we2 = 0;  // SRAM2 R
                end else begin  // 홀수
                    o_cs1 = 1;
                    o_we1 = 0;  // SRAM1 R
                    o_cs2 = 1;
                    o_we2 = 1;  // SRAM2 W
                end
            end

            ACT_LAST: begin
                // 마지막 줄 flush - only Read
                // 입력이 끝났으므로 v_cnt = VACT

                // 직전 line이 odd이면(SRAM2 저장) -> SRAM2 읽기
                if ((VACT - 1) % 2 == 1) begin
                    o_cs1 = 0;
                    o_we1 = 0;
                    o_cs2 = 1;
                    o_we2 = 0;  // SRAM2 R
                end else begin  // 직전 line이 even이면(SRAM1 저장) -> SRAM1 읽기
                    o_cs1 = 1;
                    o_we1 = 0;  // SRAM1 R
                    o_cs2 = 0;
                    o_we2 = 0;
                end
            end

            default: ;
        endcase
    end


    // Output =====================================================================================
    logic [29:0] o_mux;

    always_comb begin
        o_mux = 30'b0;

        // if (c_state == ACT_MIDDLE) begin
        if (n_state == ACT_MIDDLE) begin
            if (ram_sel == 0) begin
                o_mux = i_dout2;  // 쓰고 있는 ram의 반대를 읽음.
            end else begin
                o_mux = i_dout1;  // 쓰고 있는 ram의 반대를 읽음.
            end
            // end else if (c_state == ACT_LAST) begin
        end else if (n_state == ACT_LAST) begin
            if ((VACT - 1) % 2 == 1) begin
                o_mux = i_dout2;
            end else begin
                o_mux = i_dout1;
            end
        end
    end

    // 출력이 1 clk 밀리지 않고 바로 나오도록 설정!!
    assign o_vsync = i_vsync;
    assign o_hsync = i_hsync;

    assign o_de = (n_state == ACT_MIDDLE || n_state == ACT_LAST) ? 1'b1 : 1'b0;

    // 데이터 출력
    assign o_r = o_de ? o_mux[29:20] : 10'd0;
    assign o_g = o_de ? o_mux[19:10] : 10'd0;
    assign o_b = o_de ? o_mux[9:0] : 10'd0;
endmodule



/* 출력이 1clk 후에 출력되는 문제 발생!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // 출력 레지스터 (sync 신호와 data 신호 동시에 1 clk 지연 출력) =================================================
    always_ff @(posedge clk, negedge rstn) begin : blockName
        if (!rstn) begin
            o_de    <= 0;
            o_vsync <= 1;  // sync : active low 
            o_hsync <= 1;  // sync : active low
            o_r     <= 0;
            o_g     <= 0;
            o_b     <= 0;
        end else begin
            o_vsync <= i_vsync;
            o_hsync <= i_hsync;

            // DE 신호 생성
            // if (c_state == ACT_MIDDLE || c_state == ACT_LAST) begin
            if (n_state == ACT_MIDDLE || n_state == ACT_LAST) begin
                o_de <= 1'b1;
            end else begin
                o_de <= 1'b0;
            end

            // 데이터 래치
            o_r <= o_mux[29:20];
            o_g <= o_mux[19:10];
            o_b <= o_mux[9:0];
        end
    end
endmodule*/


/* 필요없어짐
    // 출력 타이밍 보정 ==================================================================================
    logic d_valid;  // 데이터가 유효한지
    logic d_src;  // 0: SRAM1 Read. 1: SRAM2 Read
    logic d_vsync, d_hsync;

    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            d_valid <= 0;
            d_src   <= 0;
            d_vsync <= 1;  // sync : active low 
            d_hsync <= 1;  // sync : active low
        end else begin
            d_vsync <= i_vsync;  // sync에 delay
            d_hsync <= i_hsync;  // sync에 delay

            // 유효 데이터 구간 정의
            if (c_state == ACT_MIDDLE || c_state == ACT_LAST) begin
                d_valid <= 1'b1;
            end else begin
                d_valid <= 1'b0;
            end

            // 어떤 SRAM을 읽는지 기억
            // @ACT_MIDDLE : ram_sel의 반대를 읽음
            if (c_state == ACT_MIDDLE) begin
                if (ram_sel == 0) begin
                    d_src <= 1;  // SRAM1 Write. SRAM2 Read.
                end else begin
                    d_src <= 0;  // SRAM1 Read. SRAM2 Write.
                end
            end  // @ACT_LAST : 계산한 로직 그대로
            else if (c_state == ACT_LAST) begin
                if ((VACT - 1) % 2 == 1) begin
                    d_src <= 1;  // Last stored in SRAM2
                end else begin
                    d_src <= 0;  // Last stored in SRAM1
                end
            end
        end
    end


    // Final Output Mux ===========================================================================
    logic [29:0] read_data;

    always_comb begin
        read_data = 0;
        if (d_valid) begin
            if (d_src == 0) begin
                read_data = i_dout1;
            end else begin
                read_data = i_dout2;
            end
        end
    end


    assign o_r = read_data[29:20];
    assign o_g = read_data[19:10];
    assign o_b = read_data[9:0];

    assign o_de = d_valid;  // 지연된 유효 신호가 실제 0_de가 된다.
    assign o_vsync = d_vsync;
    assign o_hsync = d_hsync;

endmodule
*/




///// 고민중 /////

// o_sel로 출력 신호 선택 -> mux필요? 그냥 case 처리해?


// scale function으로 scale 선택하는 mux?
// scale 방식 - sampling, average, cross


// [하만세미콘아카데미]1주차_과제레포트_황석현
