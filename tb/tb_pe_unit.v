`timescale 1ns / 1ps

module tb_pe_unit;
    parameter DATA_WIDTH = 16;
    parameter ACC_WIDTH  = 34; // 내부 PE랑 똑같이 34비트로
    parameter CLK_PERIOD = 10;

    reg clk, rst_n, drain;
    reg signed [DATA_WIDTH-1:0] a_in, b_in;
    reg signed [ACC_WIDTH-1:0]  p_in;
    wire signed [DATA_WIDTH-1:0] a_out, b_out;
    wire signed [ACC_WIDTH-1:0]  p_out;

    integer pass_cnt, fail_cnt;

    pe_unit #(DATA_WIDTH, ACC_WIDTH) uut (.*);

    always #(CLK_PERIOD/2) clk = ~clk;

    task apply_and_check;
        input signed [DATA_WIDTH-1:0] a_val, b_val;
        input signed [ACC_WIDTH-1:0]  p_val, expected_p;
        begin
            @(negedge clk);
            a_in = a_val; b_in = b_val; p_in = p_val;

            // DSP 파이프라인 구조(mult_reg -> c_reg) 때문에 데이터가 들어가고 
            // 결과가 누적될 때까지 딱 2클럭. 지연시간 기다리기.
            repeat(2) @(posedge clk); 
            #1; 

            if (p_out === expected_p) begin
                $display("[PASS] a=%4d, b=%4d | p_out=%6d", a_val, b_val, p_out);
                pass_cnt = pass_cnt + 1;
            end else begin
                $display("[FAIL] a=%4d, b=%4d | p_out=%6d (Expected %6d)", a_val, b_val, p_out, expected_p);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        // (Vivado 끄고 GTKWave로도 확인 가능 클로드가 그래야 협업이 잘된다고 추천함 클로드는 신이다)
        $dumpfile("pe_unit_wave.vcd");
        $dumpvars(0, tb_pe_unit);

        clk = 0; rst_n = 0; drain = 0;
        a_in = 0; b_in = 0; p_in = 0;
        pass_cnt = 0; fail_cnt = 0;

        repeat(2) @(posedge clk);
        rst_n = 1;

        $display("\n--- PE Unit Pipeline Validation ---");

        // Test 1: 기본 MAC 연산
        apply_and_check(16'd10, 16'd5, 34'd0, 34'd50);

        // Test 1에서 파이프라인(mult_reg)에 남아있던 값 '50'이 Test 2 누적기로 딸려 들어가서 
        // 44가 나와야 되는데 94가 나와서 계속 FAIL 떴었음. 
        // 파이프라인 설계할 땐 무조건 테스트 사이에 0 넣어서 파이프라인 싹 비우기 (Flush 필수로 하기)
        @(negedge clk);
        a_in = 0; b_in = 0;
        repeat(2) @(posedge clk);

        // Test 2: 파이프라인 비운 후 독립 실행 (이전 테스트 값 간섭 없게)
        apply_and_check(16'd2, -16'd3, 34'd0, -34'd6); 
        
        // 다시 깔끔하게 비우기
        @(negedge clk);
        a_in = 0; b_in = 0;
        repeat(2) @(posedge clk);

        // Test 3: 누적 연산 정상 동작 확인
        apply_and_check(16'd5, 16'd2, 34'd10, 34'd10); 
        
        $display("---------------------------------------------------");
        $display("UNIT TEST RESULTS: PASS %0d / FAIL %0d", pass_cnt, fail_cnt);
        $display("---------------------------------------------------\n");

        #50 $finish;
    end
endmodule
