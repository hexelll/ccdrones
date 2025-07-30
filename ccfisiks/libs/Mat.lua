local Mat = {
    data = {},
    cols=0,
    rows=0,
    symbolic=false,
    symbol={str=""}
}
function Mat.symbol.new(str)
    local o = {str=str}
    setmetatable(o,{
        __index=function(_,k)
            return Mat.symbol[k]
        end,
        __add=function(a,b)
            if type(a) == "table" and type(b) == "table" then
                return a:add(b)
            elseif type(a)=="table" then
                return a:add(Mat.symbol.new(tostring(b)))
            elseif type(b)=="table" then
                return b:add(Mat.symbol.new(tostring(a)))
            end
        end,
        __sub=function(a,b)
            if type(a) == "table" and type(b) == "table" then
                return a:sub(b)
            elseif type(a)=="table" then
                return a:sub(Mat.symbol.new(tostring(b)))
            elseif type(b)=="table" then
                return b:sub(Mat.symbol.new(tostring(a)))
            end
        end,
        __mul=function(a,b)
            if type(a) == "table" and type(b) == "table" then
                return a:mul(b)
            elseif type(a)=="table" then
                return a:mul(Mat.symbol.new(tostring(b)))
            elseif type(b)=="table" then
                return b:mul(Mat.symbol.new(tostring(a)))
            end
        end,
        __div=function(a,b)
            if type(a) == "table" and type(b) == "table" then
                return a:div(b)
            elseif type(a)=="table" then
                return a:div(Mat.symbol.new(tostring(b)))
            elseif type(b)=="table" then
                return b:div(Mat.symbol.new(tostring(a)))
            end
        end,
        __unm=function(a)
            if a.str == "0" then
                return a
            end
            return Mat.symbol.new('(-'..a.str..')')
        end,
        __tostring=function(a)
            return a.str
        end,
        __concat=function(a,b)
            if type(a) == "table" and type(b) == "table" then
                return a.str..b.str
            elseif type(a)=="table" then
                return a.str..tostring(b)
            elseif type(b)=="table" then
                return b.str..tostring(a)
            end
        end
    })
    return o
end
function Mat.symbol:add(b)
    if self.str == "0" then
        return Mat.symbol.new(b.str)
    end
    if b.str == "0" then
        return Mat.symbol.new(self.str)
    end
    return Mat.symbol.new("("..self.str.."+"..b.str..")")
end
function Mat.symbol:sub(b)
    if b.str == "0" then
        return Mat.symbol.new(self.str)
    end
    if self.str == "0" then
        return Mat.symbol.new("-"..b.str)
    end
    if self.str == b.str then
        return Mat.symbol.new("")
    end

    return Mat.symbol.new("("..self.str.."-"..b.str..")")
end
function Mat.symbol:mul(b)
    if self.str == "0" or self.str == "-0" or b.str == "0" or b.str == "-0" then
        return Mat.symbol.new("0")
    end
    if self.str == "1" then
        return b
    end
    if b.str == "1" then
        return self
    end
    if self.str == b.str then
        return Mat.symbol.new(self.str.."^2")
    end
    return Mat.symbol.new("("..self.str.."*"..b.str..")")
end
function Mat.symbol:div(b)
    if self.str == "0" then
        return Mat.symbol.new("0")
    end
    if self.str == b.str then
        return Mat.symbol.new("1")
    end
    if b.str == "1" then
        return self
    end
    return Mat.symbol.new("("..self.str.."/"..b.str..")")
end
function Mat.new(rows,cols,symbolic)
    local o = {data={},cols=cols,rows=rows,symbolic=symbolic}
    setmetatable(o,{
        __index=function(_,k)
            return Mat[k]
        end,
        __tostring=function()
            return o:tostring()
        end,
        __mul=function(_,B)
            return o:mul(B)
        end,
        __add=function(_,B)
            return o:add(B)
        end,
        __sub=function(_,B)
            return o:sub(B)
        end,
        __unm=function()
            return o:neg()
        end
    })
    return o
end

function Mat.identity(n,symbolic)
    local rtn = Mat.zeros(n,n,symbolic)
    for i=1,n do
        for j=1,n do
            if i==j then
                rtn.data[i][j] = 1
            end
        end
    end
    return rtn
end
function Mat.from(t,symbolic)
    local rtn = Mat.new(#t,#t[1],symbolic)
    rtn.data = t
    return rtn
end
function Mat:mul(B)
    local rtn = Mat.from(self.data)
    if type(B) == "table" and B.cols == self.cols and B.rows and self.rows then
        for i=1,self.rows do
            for j=1,self.cols do
                rtn.data[i][j] = self.data[i][j]*B.data[i][j]
            end
        end
    elseif type(B) == "number" then
        for i=1,self.rows do
            for j=1,self.cols do
                rtn.data[i][j] = self.data[i][j]*B
            end
        end
    end
    return rtn
end
function Mat:add(B)
    local rtn = Mat.zeros(self.rows,self.cols)
    if type(B) == "table" and B.cols == self.cols and B.rows and self.rows then
        for i=1,self.rows do
            for j=1,self.cols do
                rtn.data[i][j] = self.data[i][j]+B.data[i][j]
            end
        end
    elseif type(B) == "number" then
        for i=1,self.rows do
            for j=1,self.cols do
                rtn.data[i][j] = self.data[i][j]+B
            end
        end
    end
    return rtn
end
function Mat:sub(B)
    local rtn = Mat.from(self.data)
    if type(B) == "table" and B.cols == self.cols and B.rows and self.rows then
        for i=1,self.rows do
            for j=1,self.cols do
                rtn.data[i][j] = self.data[i][j]-B.data[i][j]
            end
        end
    elseif type(B) == "number" then
        for i=1,self.rows do
            for j=1,self.cols do
                rtn.data[i][j] = self.data[i][j]-B
            end
        end
    end
    return rtn
end
function Mat:neg()
    return self:mul(-1)
end
function Mat.zeros(rows,cols,symbolic)
    local rtn = Mat.new(rows,cols,symbolic)
    for i=1,rows do
        rtn.data[i] = {}
        for j=1,cols do
            rtn.data[i][j] = 0
        end
    end
    return rtn
end
function Mat:matMul(B)
    if self.cols == B.rows then
        local rtn = Mat.zeros(self.rows,B.cols)
        for i=1,self.rows do
            for j=1,B.cols do
                for k=1,self.cols do
                    rtn.data[i][j] = rtn.data[i][j]+self.data[i][k]*B.data[k][j]
                end
            end
        end
        return rtn
    else
        error("incorrect matrix sizes")
    end
end
function Mat:tostring()
    local buf = ""
    for i=1,self.rows do
        buf=buf.."["
        for j=1,self.cols do
            buf = buf..self.data[i][j]..","
        end
        buf=buf.."]\n"
    end
    return buf
end
function Mat:map(fn)
    local newMat = Mat.from(self.data)
    for i=1,self.rows do
        for j=1,self.cols do
            newMat.data[i][i] = fn(self.data[i][j])
        end
    end
    return newMat
end
function Mat:copy()
    local data = {}
    for i=1,self.rows do
        data[i] = {}
        for j=1,self.cols do
            data[i][j] = self.data[i][j]
        end
    end
    return Mat.from(data,self.symbolic)
end

function Mat:trace()
    local trace = 1
    for i=1,self.cols do
        trace = trace * self.data[i][i]
    end
    return trace
end

function Mat:line_swap(l1,l2)
    self.data[l1],self.data[l2] = self.data[l2],self.data[l1]
    return self
end
function Mat:line_mul(l,k)
    for i = 1,self.cols do
        self.data[l][i] = self.data[l][i]*k
    end
    return self
end
function Mat:line_add(l1,l2,k)
    for i = 1,self.cols do
        self.data[l1][i] = self.data[l1][i]+self.data[l2][i]*k
    end
    return self
end
function Mat:gauss(b)
    local A = self:copy()
    local B = b:copy()
    local n = A.cols
    if not self.symbolic then
        for k=1,n do
            local imax = k
            local vmax = math.abs(A.data[imax][k])
            
            for i=k+1,n do
                if math.abs(A.data[i][k]) > vmax then
                    vmax = A.data[i][k]
                    imax = i
                end
            end
            if imax ~= k then
                A:line_swap(k,imax)
                B:line_swap(k,imax)
            end
        end
    end
    for i=1,n+1 do
        for j=2,n do
            if i<j then
                local k = -A.data[j][i]/A.data[i][i]
                A:line_add(j,i,k)
                B:line_add(j,i,k)
            end
        end
    end
    local det = A:trace()
    if not self.symbolic then
        if math.abs(det) < 0.0001 then
            error("matrix not inversible")
        end
    else
        print("det:",det)
    end
    for i=1,n do
        local k = 1/A.data[i][i]
        A:line_mul(i,k)
        B:line_mul(i,k)
    end
    for i=1,n do
        for j=1,i-1 do
            local k = -A.data[j][i]
            A:line_add(j,i,k)
            B:line_add(j,i,k)
        end
    end
    return B
end
function Mat:inverse()
    local A = self:copy()
    local B = Mat.identity(A.cols,self.symbolic)
    return A:gauss(B)
end

function Mat.rotation2D(a)
    return Mat.from{
        {math.cos(a),-math.sin(a),0},
        {math.sin(a),math.cos(a),0},
        {0,0,1}
    }
end

function Mat.rotateAndZoom(px,py,scale,ratioT,ratioS,a)
    a = a or 0
    local ratio = ratioS * ratioT
    local ca = math.cos(a)
    local sa = math.sin(a)
    local rr = ratioT
    local si = 1/scale
    local sn = -si*0.5
    local rsi = ratioS*si
    local cx = ratioS*(px+sn)
    local cy = (py+sn)
    return Mat.from{
                {rr*ca*rsi,-rr*sa*si,rr*(ca*cx-sa*cy+0.5/ratioS)},
                {sa*rsi,ca*si,sa*cx+ca*cy+0.5},
                {0,0,1}
            }
end

return Mat