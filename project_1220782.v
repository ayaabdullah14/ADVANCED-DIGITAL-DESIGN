module project ( input [5:0] A,  input [5:0] B,input Selection,clk, output Equal, Greater, Smaller );               
  
    // Internal synchronized signals
    wire [5:0] A_synch;
    wire [5:0] B_synch;
    wire overflow;
   
    wire [2:0] compare_signed;  
    wire [2:0] compare_unsigned; 
    wire [2:0] MUX_out;          

    // Register  for A
    Register_6bit U10 ( .clk(clk), .D_in(A),  .Q_out(A_synch) ); 
	
    // Register  for B
    Register_6bit U11 (.clk(clk),.D_in(B),.Q_out(B_synch)   ); 
         
    SignedComparator Comsigned (A_synch, B_synch, compare_signed[2], compare_signed[1], compare_signed[0]);   // Signed comparison
    comparator Comunsigned (A_synch, B_synch, compare_unsigned[2], compare_unsigned[1], compare_unsigned[0]);  // Unsigned comparison
																						
    // Multiplexer to choose between signed and unsigned comparison results
    MUX_2to1 MUX ( .SelectSignal(Selection),.UnsignedCompareResult(compare_unsigned),.SignedCompareResult(compare_signed),  .MUXOutput(MUX_out)  );
 
    // Register  for the output
    Register_3bit Reg ( .clk(clk),.D_in(MUX_out), .Q_out({Equal, Greater, Smaller})  );
        
endmodule
///////////////////////////////////
// 6-bit Register for inputs 
module Register_6bit (  input clk, input [5:0] D_in,  output reg [5:0] Q_out);     

    always @(posedge clk ) begin
            Q_out <= D_in;  // Load the input data on the clock edge
        end
endmodule

//////////////////////////////////////////////////
// Register 3-bit for  output
module Register_3bit ( input clk, input [2:0] D_in, output reg [2:0] Q_out);
  
  always @(posedge clk) begin
            Q_out <= D_in;  
        end
    
endmodule
						
///////////////////////////////////////////////////////////////	
module comparator( input [5:0] inputA, inputB,output is_equal,is_greater,is_less );         

    wire [5:0] xor_results;        
    wire [5:0] inverted_xor;        
    wire [5:0] greater_flags;       
    wire [5:0] less_flags;          
    wire [5:0] inverted_A;          
    wire [5:0] inverted_B;          
    wire [5:0] equality_flags;      
    // Invert the bits of input_A and input_B
    genvar bitIndex;
    generate
        for (bitIndex = 0; bitIndex < 6; bitIndex = bitIndex + 1) begin
            not #1 (inverted_A[bitIndex], inputA[bitIndex]); // Invert each bit of input_A
            not #1 (inverted_B[bitIndex], inputB[bitIndex]); // Invert each bit of input_B
        end
    endgenerate

    
    generate
        for (bitIndex = 0; bitIndex< 6; bitIndex = bitIndex+ 1) begin
            xor #7 (xor_results[bitIndex], inputA[bitIndex], inputB[bitIndex]); 
            not #1 (inverted_xor[bitIndex], xor_results[bitIndex]);              
        end
    endgenerate

    // Check if all bits are equal (input_A == input_B)
    and #4 (is_equal, inverted_xor[0], inverted_xor[1], inverted_xor[2], 
                        inverted_xor[3], inverted_xor[4], inverted_xor[5]); 
 
not #1 (equality_flags[5], xor_results[5]); 
generate
    for (bitIndex = 4; bitIndex >= 0; bitIndex = bitIndex - 1) begin
        wire inverted_xor_bit;               
        not #1 (inverted_xor_bit, xor_results[bitIndex]); 
        and #4 (equality_flags[bitIndex], equality_flags[bitIndex+1], inverted_xor_bit); 
    end
endgenerate


    // Generate flags for greater-than conditions
    and #4 (greater_flags[5], inputA[5], inverted_B[5]); // input_A[5] > input_B[5]
    and #4 (less_flags[5], inverted_A[5], inputB[5]);    // input_A[5] < input_B[5]
    generate
        for (bitIndex = 4; bitIndex >= 0; bitIndex = bitIndex - 1) begin
            and #4 (greater_flags[bitIndex], equality_flags[bitIndex+1], inputA[bitIndex], inverted_B[bitIndex]); 
            and #4 (less_flags[bitIndex], equality_flags[bitIndex+1], inverted_A[bitIndex], inputB[bitIndex]);   
        end
    endgenerate

    // Combine greater-than flags to determine if input_A > input_B
    or #5 (is_greater, greater_flags[0], greater_flags[1], greater_flags[2],  greater_flags[3], greater_flags[4], greater_flags[5]); 
    // Combine less-than flags to determine if input_A < input_B
    or #5 (is_less, less_flags[0], less_flags[1], less_flags[2],  less_flags[3], less_flags[4], less_flags[5]); 
                     

endmodule

///////////////////////////////
module MUX_2to1 ( input SelectSignal,input [2:0] UnsignedCompareResult ,SignedCompareResult, output [2:0] MUXOutput);  
                  
    wire InvertedSelect;               
    wire [2:0] UnsignedANDResults;      
    wire [2:0] SignedANDResults;      


    not   #1 (InvertedSelect, SelectSignal);

 
    and #4 (UnsignedANDResults[0], UnsignedCompareResult[0], InvertedSelect);
    and #4 (UnsignedANDResults[1], UnsignedCompareResult[1], InvertedSelect);
    and #4 (UnsignedANDResults[2], UnsignedCompareResult[2], InvertedSelect);

    and #4 (SignedANDResults[0], SignedCompareResult[0], SelectSignal);
    and #4 (SignedANDResults[1], SignedCompareResult[1], SelectSignal);
    and #4 (SignedANDResults[2], SignedCompareResult[2], SelectSignal);

  
    or #5 (MUXOutput[0], UnsignedANDResults[0], SignedANDResults[0]);
    or #5 (MUXOutput[1], UnsignedANDResults[1], SignedANDResults[1]);
    or #5 (MUXOutput[2], UnsignedANDResults[2], SignedANDResults[2]);

endmodule

	
//////////////////////////////// 
module SignedComparator (
    input [5:0] A,  
    input [5:0] B,   
    output A_eq_B,    
    output A_gt_B,   
    output A_lt_B   
);

 
    wire n_A5, n_B5; // Negated sign bits (most significant bits)
    wire [5:0] eq;    // Equality signals for each bit
    wire [5:0] gt_pos, lt_pos; // Comparison signals for positive numbers
    wire [5:0] gt_neg, lt_neg; // Comparison signals for negative numbers
    wire A_gt_B_int, A_lt_B_int, A_eq_B_int;

    // Negate the sign bits with delay (INV = 1 time unit)
    not #1 (n_A5, A[5]);
    not #1 (n_B5, B[5]);

    // Equality comparison using XNOR with delay 
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : eq_gen
            xnor #6 (eq[i], A[i], B[i]);
        end
    endgenerate

    // AND gate for equality check with delay
    and #4 (A_eq_B, eq[5], eq[4], eq[3], eq[2], eq[1], eq[0]);

    // Case 1: A is positive and B is negative -> A > B
    wire positive_A, negative_B;
    and #4 (positive_A, n_A5, B[5]); // A is positive and B is negative
    and #4 (negative_B, A[5], n_B5); // A is negative and B is positive

    // Negations for each bit in A and B for comparison
    wire [5:0] n_A, n_B;
    generate
        for (i = 0; i < 6; i = i + 1) begin : neg_gen
            not #1 (n_A[i], A[i]);
            not #1 (n_B[i], B[i]);
        end
    endgenerate

    // Greater than comparison for positive numbers with delay (AND = 4 time units)
    and #4 (gt_pos[5], eq[5], A[4], n_B[4]);
    and #4 (gt_pos[4], eq[5], eq[4], A[3], n_B[3]);
    and #4 (gt_pos[3], eq[5], eq[4], eq[3], A[2], n_B[2]);
    and #4 (gt_pos[2], eq[5], eq[4], eq[3], eq[2], A[1], n_B[1]);
    and #4 (gt_pos[1], eq[5], eq[4], eq[3], eq[2], eq[1], A[0], n_B[0]);
    or #5 (gt_pos[0], gt_pos[5], gt_pos[4], gt_pos[3], gt_pos[2], gt_pos[1]);

    // Less than comparison for positive numbers with delay (AND = 4 time units)
    and #4 (lt_pos[5], eq[5], n_A[4], B[4]);
    and #4 (lt_pos[4], eq[5], eq[4], n_A[3], B[3]);
    and #4 (lt_pos[3], eq[5], eq[4], eq[3], n_A[2], B[2]);
    and #4 (lt_pos[2], eq[5], eq[4], eq[3], eq[2], n_A[1], B[1]);
    and #4 (lt_pos[1], eq[5], eq[4], eq[3], eq[2], eq[1], n_A[0], B[0]);
    or #5 (lt_pos[0], lt_pos[5], lt_pos[4], lt_pos[3], lt_pos[2], lt_pos[1]);

    // Case 3: Both A and B are negative -> compare magnitudes (reverse logic)
    // Greater than comparison for negative numbers with delay (AND = 4 time units)
    and #4 (gt_neg[5], A[5], eq[5], n_B[4], A[4]);
    and #4 (gt_neg[4], A[5], eq[5], eq[4], n_B[3], A[3]);
    and #4 (gt_neg[3], A[5], eq[5], eq[4], eq[3], n_B[2], A[2]);
    and #4 (gt_neg[2], A[5], eq[5], eq[4], eq[3], eq[2], n_B[1], A[1]);
    and #4 (gt_neg[1], A[5], eq[5], eq[4], eq[3], eq[2], eq[1], n_B[0], A[0]);
    or #5 (gt_neg[0], gt_neg[5], gt_neg[4], gt_neg[3], gt_neg[2], gt_neg[1]);

    // Less than comparison for negative numbers with delay (AND = 4 time units)
    and #4 (lt_neg[5], B[5], eq[5], n_A[4], B[4]);
    and #4 (lt_neg[4], B[5], eq[5], eq[4], n_A[3], B[3]);
    and #4 (lt_neg[3], B[5], eq[5], eq[4], eq[3], n_A[2], B[2]);
    and #4 (lt_neg[2], B[5], eq[5], eq[4], eq[3], eq[2], n_A[1], B[1]);
    and #4 (lt_neg[1], B[5], eq[5], eq[4], eq[3], eq[2], eq[1], n_A[0], B[0]);
    or #5 (lt_neg[0], lt_neg[5], lt_neg[4], lt_neg[3], lt_neg[2], lt_neg[1]);

    // Final Assignment for A_gt_B using OR gates with delay (OR = 5 time units)
    or #5 (A_gt_B_int, positive_A, gt_pos[0], gt_neg[0]);

    // Final Assignment for A_lt_B using OR gates with delay (OR = 5 time units)
    or #5 (A_lt_B_int, negative_B, lt_pos[0], lt_neg[0]);

    // Output assignments
    assign A_gt_B = A_gt_B_int;
    assign A_lt_B = A_lt_B_int;

endmodule

 ////////////////////////////////////////////////////////////////////////////////////////////////////
 
module Comparator_bahivoral(
    input [5:0] A, B,
    input S,           
    output reg Equal,   
    output reg Greater,
    output reg Smaller  
);

   
    wire signed [5:0] signed_A, signed_B;
    wire unsigned_gt, unsigned_lt, unsigned_eq;
    wire signed_gt, signed_lt, signed_eq;
   
    assign signed_A = $signed(A);  
    assign signed_B = $signed(B); 
		
    assign unsigned_gt = (A > B);
    assign unsigned_lt = (A< B);
    assign unsigned_eq = (A == B);

  
    assign signed_gt = (signed_A > signed_B);
    assign signed_lt = (signed_A < signed_B);
    assign signed_eq = (signed_A == signed_B);
  
    always @(*) begin
        if (S == 1) begin
            Equal    <= signed_eq; 
            Greater  <= signed_gt; 
            Smaller  <= signed_lt;  
        end else begin
            Equal    <= unsigned_eq;  
            Greater  <= unsigned_gt;  
            Smaller  <= unsigned_lt;  
        end
    end

endmodule


////////////////////////////////
module test_project;
    reg [5:0] A, B;            
    reg Selection;                
    reg clk;                
    wire Equal_project, Greater_project, Smaller_project; 
    wire Equal_bahivoral, Greater_bahivoral, Smaller_bahivoral; 

    integer pass_count = 0, fail_count = 0; 

    project u (
        .A(A), 
        .B(B),
        .Selection(Selection),
        .clk(clk),
        .Equal(Equal_project),  
        .Greater(Greater_project),    
        .Smaller(Smaller_project)
    );
    
    Comparator_bahivoral COMP (
        .A(A),  
        .B(B),
        .S(Selection),
        .Equal(Equal_bahivoral),
        .Greater(Greater_bahivoral),   
        .Smaller(Smaller_bahivoral)
    );
  
    initial begin
        clk = 0;
        forever #25 clk = ~clk; 
    end

    initial begin
        integer i; 
        $display("Starting random test cases.\n");

        for (i = 0; i < 8000; i = i + 1) begin
            #30; 
            A = $random % 64; 
            B = $random % 64; 
            Selection = $random % 2;

            #150;

            if ((Equal_project === Equal_bahivoral) &&
                (Greater_project === Greater_bahivoral) &&
                (Smaller_project === Smaller_bahivoral)) begin
                pass_count = pass_count + 1;
                $display("Test Case %0d - PASS: A = %b, B = %b, Selection = %b", 
                          i + 1, A, B, Selection);  
                $display("    Project Module: Equal = %b, Greater = %b, Smaller = %b", Equal_project, Greater_project, Smaller_project); 
                $display("    Behavioral Module: Equal = %b, Greater = %b, Smaller = %b", Equal_bahivoral, Greater_bahivoral, Smaller_bahivoral); 
                $display("-------------------------------------------\n");
            end else begin
                fail_count = fail_count + 1;
                $display("Test Case %0d - FAIL: A = %b, B = %b, Selection = %b", i + 1, A, B, Selection);
                        
                if (Equal_project !== Equal_bahivoral)
                    $display("    MISMATCH: Equal_project = %b, Equal_bahivoral = %b", Equal_project, Equal_bahivoral);
                if (Greater_project !== Greater_bahivoral)
                    $display("    MISMATCH: Greater_project = %b, Greater_bahivoral = %b", Greater_project, Greater_bahivoral);
                if (Smaller_project !== Smaller_bahivoral)
                    $display("    MISMATCH: Smaller_project = %b, Smaller_bahivoral = %b", Smaller_project, Smaller_bahivoral);
                $display("-------------------------------------------\n");
            end
        end

        $display("Random test cases completed.");
        $display("Test Summary: %0d PASS, %0d FAIL", pass_count, fail_count);
        $finish;
    end
endmodule

