`timescale 1ns / 1ps

module pe_unit #(
    parameter DATA_WIDTH = 16,
    //16비트끼리 곱하면 32비트, 이걸 4번 누적하니까 
    // 혹시 모를 오버플로우 방지용으로 34비트로 확장함. 
    parameter ACC_WIDTH  = 34 
)(
    input clk, rst_n, drain,
    input  signed [DATA_WIDTH-1:0] a_in, b_in,
    input  signed [ACC_WIDTH-1:0]  p_in,
    output reg signed [DATA_WIDTH-1:0] a_out, b_out,
    output signed [ACC_WIDTH-1:0] p_out
);
    reg signed [ACC_WIDTH-1:0] c_reg;
    
    //  Vivado가 자꾸 무거운 곱셈을 LUT로 합성해버려서 강제로 DSP48E1을 쓰도록 유도함.
    //  1-cycle 파이프라인 레지스터(mult_reg)를 둬서
    // DSP 내부 P-register 구조에  매핑으로 강제로 DSP사용후 LUT급감 (LUT 1392 -> 513 )
    (* use_dsp = "yes" *) 
    reg signed [ACC_WIDTH-1:0] mult_reg;

    always @(posedge clk or negedge rst_n) begin
        // 처음에 여기 리셋 안 걸어줬더니 시뮬레이션 돌릴 때 
        // 빨간색 X값이 어레이 전체로 퍼짐 (X-propagation 해결 완료)
        if (!rst_n) mult_reg <= 0;
        else        mult_reg <= a_in * b_in;
    end

    assign p_out = c_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 0; b_out <= 0; c_reg <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            // 계산 다 끝나고 누적된 결과(Partial Sum)를 아래 PE로 흘려보낼 때 (Drain 모드)
            if (drain) c_reg <= p_in;
            // 평소에는 MAC 연산 (기존 누적값 + 방금 파이프라인에서 넘어온 곱셈 값)
            else       c_reg <= c_reg + mult_reg;
        end
    end
endmodule
