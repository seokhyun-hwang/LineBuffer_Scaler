`timescale 1ns / 1ps

// 역할: 데이터 저장, 건너뛰며 읽어(Sampling), 크기 줄여(ScaleDown) 내보냄.
module Scaler_Ctrl #(  // TOP에서 값 변경 가능
    parameter int HACT = 10,
    parameter int VACT = 4,
    parameter int SCALE_RATIO = 2,  // 몇 배로 줄일지 (1,2,3..)
    parameter int H_OUT = 5  // 출력 가로 픽셀 수 (TOP에서 계산)
) (
    input logic clk,
    input logic rstn,

    input logic       i_de,
    input logic [9:0] i_r_data,
    input logic [9:0] i_g_data,
    input logic [9:0] i_b_data,
    input logic       i_vsync,
    input logic       i_hsync,

    output logic [9:0] o_r_data,
    output logic [9:0] o_g_data,
    output logic [9:0] o_b_data,
    output logic       o_vsync,
    output logic       o_hsync,
    output logic       o_de,      // 줄어든 만큼만 1

    output logic        o_cs1,
    output logic        o_we1,
    output logic [ 5:0] o_addr1,
    output logic [29:0] o_din1,
    input  logic [29:0] i_dout1,

    output logic        o_cs2,
    output logic        o_we2,
    output logic [ 5:0] o_addr2,
    output logic [29:0] o_din2,
    input  logic [29:0] i_dout2
);

    // FSM state ==================================================================================
    typedef enum logic [2:0] {
        IDLE,
        WAIT_DE,
        ACT_FIRST,
        ACT_MIDDLE,
        WAIT_FLUSH,
        ACT_LAST
    } state_t;

    state_t c_state, n_state;


    // Counter ====================================================================================
    logic [5:0] cnt_w;  // WRITE counter - 입력 pixel 수 세기 (0~HACT)
    logic [5:0] cnt_r;  // READ counter - 출력 pixel 수 세기 (0~H_OUT)
    logic [5:0] v_cnt;  // LINE counter - 몇번 째 줄인지 세기


    // Edge Detector ==============================================================================
    logic vsync_d, hsync_d, de_d;
    wire de_fall = (!i_de && de_d);  // 한 line 입력 종료 감지
    wire vsync_start = (!i_vsync && vsync_d);  // 프레임 시작 Falling Edge
    wire hsync_start = (!i_hsync && hsync_d);  // 라인 종료 Falling Edge (Active Low)

    // data concatenation
    logic [29:0] din_con;
    assign din_con = {i_r_data, i_g_data, i_b_data};


    // 신호 동기화 =====================================================================================
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
                    if (v_cnt == 0) begin  // 첫번째 줄이면 - 쓰기
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

            WAIT_FLUSH: begin  // 안정적인 타이밍을 위해 다음 hsync 기다렸다가 쏨
                if (hsync_start) begin
                    n_state = ACT_LAST;
                end
            end

            ACT_LAST: begin  // 읽기 카운터 출력 개수(H_OUT)을 다 채우면 종료
                if (cnt_r == H_OUT) begin
                    n_state = IDLE;
                end
            end

            default: n_state = IDLE;
        endcase
    end

    // 카운터 로직 =====================================================================================
    // [WRITE Counter] i_de가 있을 때 입력 수 만큼 증가.
    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            cnt_w <= 0;
        end else begin
            if (n_state == ACT_FIRST || n_state == ACT_MIDDLE) begin  // WRITE 중
                cnt_w <= cnt_w + 1;
            end else begin
                cnt_w <= 0;
            end
        end
    end

    // [READ Counter] 출력 개수(H_OUT)만큼만 증가. -> ratio에 따라 줄어듦.
    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            cnt_r <= 0;
        end else begin
            // if ((n_state != c_state) && (n_state != ACT_MIDDLE) && (n_state != ACT_LAST)) begin  // 한 줄 다 읽음
            if ((n_state != ACT_MIDDLE) && (n_state != ACT_LAST)) begin  // 한 줄 다 읽음
                cnt_r <= 0;
            end else begin  // READ 중.
                if (cnt_r < H_OUT) begin
                    if (n_state == ACT_LAST || i_de) begin  // MIDDLE: i_de일 때 증가 / LAST: 무조건 증가
                        cnt_r <= cnt_r + 1;
                        //end
                    end
                end
            end
        end
    end

    // [LINE Counter]
    always_ff @(posedge clk, negedge rstn) begin
        if (!rstn) begin
            v_cnt <= 0;
        end else begin
            if (vsync_start) begin
                v_cnt <= 0;
            end else if (de_fall) begin
                v_cnt <= v_cnt + 1;
            end
        end
    end


    // SRAM 제어 ====================================================================================
    logic ram_sel;
    assign ram_sel = v_cnt[0];  // 0: Even, 1: Odd

    // Sampling 주소 계산 : READ Counter(cnt_r) * Scale Ratio
    logic [5:0] read_addr;
    assign read_addr = cnt_r * SCALE_RATIO;

    always_comb begin
        o_cs1   = 0;
        o_we1   = 0;
        o_addr1 = cnt_w;
        o_din1  = din_con;
        o_cs2   = 0;
        o_we2   = 0;
        o_addr2 = cnt_r;
        o_din2  = din_con;

        case (n_state)
            ACT_FIRST: begin
                o_cs1 = 1;
                o_we1 = 1;
            end

            ACT_MIDDLE: begin
                if (ram_sel == 0) begin
                    o_cs1   = 1;
                    o_we1   = 1;  // SRAM1 W / 현재 데이터 저장
                    o_cs2   = 1;
                    o_we2   = 0;  // SRAM2 R / 이전 데이터 읽기
                    o_addr2 = read_addr;  // 점프한 주소
                end else begin
                    o_cs1   = 1;
                    o_we1   = 0;  // SRAM1 R / 이전 데이터 읽기
                    o_addr1 = read_addr;  // 점프한 주소
                    o_cs2   = 1;
                    o_we2   = 1;  // SRAM2 W / 현재 데이터 저장
                end
            end

            ACT_LAST: begin
                // 마지막 줄 flush - only Read
                // 입력이 끝났으므로 v_cnt = VACT
                // 직전 line이 odd이면(SRAM2 저장) -> SRAM2 읽기
                if ((VACT - 1) % 2 == 1) begin
                    o_cs2   = 1;
                    o_we2   = 0;
                    o_addr2 = read_addr;
                end else begin  // 직전 line이 even이면(SRAM1 저장) -> SRAM1 읽기
                    o_cs1   = 1;
                    o_we1   = 0;  // SRAM1 R
                    o_addr1 = read_addr;
                end
            end

            default: ;
        endcase
    end


    // Output =====================================================================================
    logic [29:0] o_mux;

    always_comb begin
        o_mux = 30'b0;

        if (n_state == ACT_MIDDLE) begin
            if (ram_sel == 0) begin
                o_mux = i_dout2;  // 쓰고 있는 ram의 반대를 읽음.
            end else begin
                o_mux = i_dout1;  // 쓰고 있는 ram의 반대를 읽음.
            end
        end else if (n_state == ACT_LAST) begin
            if ((VACT - 1) % 2 == 1) begin
                o_mux = i_dout2;
            end else begin
                o_mux = i_dout1;
            end
        end
    end


    // 출력이 1 clk 밀리지 않고 입력 그대로 바로 나오도록 설정!!
    assign o_vsync = i_vsync;
    assign o_hsync = i_hsync;

    // 읽기 카운터가 H_OUT 이내일 때만 DE = 1
    logic de_con;
    assign de_con = (cnt_r < H_OUT);

    assign o_de = ((n_state == ACT_MIDDLE || n_state == ACT_LAST) && de_con) ? 1'b1 : 1'b0;

    // 데이터 출력
    assign o_r_data = o_de ? o_mux[29:20] : 10'd0;
    assign o_g_data = o_de ? o_mux[19:10] : 10'd0;
    assign o_b_data = o_de ? o_mux[9:0] : 10'd0;

endmodule
