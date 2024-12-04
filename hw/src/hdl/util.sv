`ifndef UTIL_SV
`define UTIL_SV

`define pipe(ty, ident, delay)                          \
    _``ident``_pipe[delay-1];                           \
    ty [delay-1:0] _``ident``_pipe;                     \
    always_ff @(posedge clk_in) begin                   \
        _``ident``_pipe[0] <= ident;                    \
    end                                                 \
    for (genvar i = 1; i < delay; i += 1) begin         \
        always_ff @(posedge clk_in) begin               \
            _``ident``_pipe[i] <= _``ident``_pipe[i-1]; \
        end                                             \
    end                                                 \

`endif