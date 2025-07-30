local vec2_ = {
    x=0,
    y=0
}

function vec2_.new(x,y)
    local o = {x=x,y=y}
    setmetatable(o,{
        __index=function(_,k)
            return vec2_[k]
        end,
        __add=function(a,b)
            if type(a)==type(b) then
                return vec2(a.x+b.x,a.y+b.y)
            elseif type(a)=='table' then
                return vec2(a.x+b,a.y+b)
            elseif type(b)=='table' then
                return vec2(a+b.x,a+b.y)
            end
        end,
        __sub=function(a,b)
            if type(a)==type(b) then
                return vec2(a.x-b.x,a.y-b.y)
            elseif type(a)=='table' then
                return vec2(a.x-b,a.y-b)
            elseif type(b)=='table' then
                return vec2(a-b.x,a-b.y)
            end
        end,
        __unm=function(a)
            return vec2(-a.x,-a.y)
        end,
        __mul=function(a,b)
            if type(a)==type(b) then
                return vec2(a.x*b.x,a.y*b.y)
            elseif type(a)=='table' then
                return vec2(a.x*b,a.y*b)
            elseif type(b)=='table' then
                return vec2(a*b.x,a*b.y)
            end
        end,
        __div=function(a,b)
            if type(a)==type(b) then
                return vec2(a.x/b.x,a.y/b.y)
            elseif type(a)=='table' then
                return vec2(a.x/b,a.y/b)
            elseif type(b)=='table' then
                error("number/vector is undefined")
            end
        end,
        __eq=function(a,b)
            return a.x==b.x and a.y==b.y
        end,
        __len=function(a)
            return math.sqrt(a.x*a.x+a.y*a.y)
        end,
        __pow=function(a)
            return vec2(a.x*a.x,a.y*a.y)
        end,
        __tostring=function(a)
            return '('..a.x..','..a.y..')'
        end,
    })
    return o
end

function vec2_:dot(v)
    return self.x*v.x+self.y*v.y
end

function vec2_:normal()
    return vec2(-self.y,self.x)
end

function vec2_:cpy()
    return vec2(self.x,self.y)
end

function vec2_:rotate(a)
    local ca = math.cos(a)
    local sa = math.sin(a)
    return vec2(ca*self.x-sa*self.y,ca*self.y+sa*self.x)
end

function vec2_:clampLength(l)
    local len = #self
    len = len>l and l or len
    local v = self:cpy()
    if #v ~= 0 then
        v = v/#v
    end
    return v*len
end

function vec2_.cross(a,b)
    if type(a)==type(b) then
        return a.x*b.y-a.y*b.x
    elseif type(a)=='table' then
        return vec2(b*a.y,-b*a.x)
    elseif type(b)=='table' then
        return vec2(-a*b.y,a*b.x)
    end
end



function vec2(x,y)
    x = x or 0
    y = y or 0
    return vec2_.new(x,y)
end

return {vec2=vec2,vec2_=vec2_}