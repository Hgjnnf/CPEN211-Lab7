module cpu(clk, reset, s, load, in, out, N, V, Z, w);
    input clk, reset, s, load;
    input [15:0] in;
    output [15:0] out;
    output reg N, V, Z, w;

    // States
    parameter Swait = 4'b0000, Sdecode = 4'b0001, SgetA = 4'b0010, SgetB = 4'b0011, Swrite = 4'b0100, Srewrite = 4'b0101, Salu = 4'b0110, Sshift = 4'b0111, Sloadout = 4'b1000;

    // Decoder Input
    wire [15:0] decoder_in;

    // Decoder Outputs
    reg [1:0] op, shift;
    reg [15:0] sximm5, sximm8;
    reg [2:0] opcode, readnum, writenum;
    reg [3:0] state;

    // nsel  
    reg [2:0] nsel;

    // Datapath Inputs
    reg [1:0] vsel;
    reg loada, loadb, asel, bsel, loadc, loads, write;
    wire [2:0] Z_out;

    // Instruction Register
    vDFFE #(16) Instruct_Reg(clk, load, in, decoder_in);

    // Instruction Decoder
    always@(*) begin
        op = decoder_in[12:11];
        sximm5 = { {11{decoder_in[4]}}, decoder_in[4:0] };
        sximm8 = { {8{decoder_in[7]}}, decoder_in[7:0] };
        shift = decoder_in[4:3];
        opcode = decoder_in[15:13];
    end

    //nsel MUX
    always@(*)begin
       case(nsel)
            3'b001: begin
                readnum = decoder_in[2:0];
                writenum = decoder_in[2:0];
            end // Rm
            3'b010: begin
                readnum = decoder_in[7:5];
                writenum = decoder_in[7:5];
            end // Rd
            3'b100: begin
                readnum = decoder_in[10:8];
                writenum = decoder_in[10:8];
            end // Rn
            default: {readnum, writenum} = 3'b0;
        endcase 
    end

    // State Machine (Mealy)
    always @(posedge clk) begin
        if(reset == 1'b1) {w, state} = {1'b1, Swait};
        else begin
            case(state)
                Sdecode: begin
                    if(opcode == 3'b110 && op == 2'b10) {w, state} = {1'b0, Swrite};
                    else {w, state} = {1'b0, SgetA};
                end
                Swrite: state = Swait;
                Swait: begin 
                    state = (s == 1'b1) ? Sdecode : Swait;
                    w = 1'b1;
                end
                SgetA: state = SgetB;
                SgetB: begin
                    if(opcode == 3'b110 && op == 2'b0) state = Sshift;
                    else if(opcode == 3'b101) state = Salu;
                end
                Salu: state = Sloadout;
                Sshift: state = Sloadout;
                Sloadout: state = Srewrite;
                Srewrite: state = Swait;
                default: {state, w} = {Swait, 1'b1};
            endcase
        end

        // output of different states
        case(state)
            SgetA: {nsel, loada, loadb} = {3'b100, 1'b1, 1'b0};
            SgetB: {nsel, loadb, loada} = {3'b001, 1'b1, 1'b0};
            Salu: {asel, bsel} = {1'b0, 1'b0};
            Sshift: {asel, bsel} = {1'b1, 1'b0};
            Sloadout: {loadc, loads} = {1'b1, 1'b1};
            Srewrite: {vsel, nsel, write} = {2'b0, 3'b010, 1'b1};
            Swrite: {vsel, nsel, write} = {2'b10, 3'b100, 1'b1};
            default: begin 
                {nsel, vsel} = {3'b0, 2'b0};
                {loada, loadb, loadc, loads, asel, bsel, write} = 1'b0;
            end
        endcase
    end

    // Datapath Instantiation
    datapath DP(
        .clk(clk), 
        .readnum(readnum), 
        .vsel(vsel), 
        .loada(loada), 
        .loadb(loadb), 
        .shift(shift),
        .asel(asel),
        .bsel(bsel),
        .ALUop(op),
        .loadc(loadc),
        .loads(loads),
        .writenum(writenum),
        .write(write),
        .mdata(16'b0),
        .PC(8'b0),
        .sximm5(sximm5),
        .sximm8(sximm8),
        .Z_out(Z_out),
        .datapath_out(out)
    );

    // Assigning V, N, Z from Z_out
    always @(*) begin
        V = Z_out[2];
        N = Z_out[1];
        Z = Z_out[0];
    end

endmodule