// Returns number of bits required to represent the input value
function integer clog2;
    input integer value;
    integer temp;

    begin
        if(value == 0 || value == 1) begin
            clog2 = 1;
        end
        else begin
            temp = value - 1;
            for(clog2 = 0; temp > 0; clog2 = clog2 + 1) begin
                temp = temp >> 1;
            end
        end
    end
endfunction
