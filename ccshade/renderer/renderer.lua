package.path =";/ccshade/renderer/?.lua"
local deepcpy = require"libs.deepcpy"
local box = require"libs.pixelbox_lite"
local Mat = require"libs.Mat"
local utils = require"libs.utils"

local _colors = {
        colors.white,
        colors.orange,
        colors.magenta,
        colors.lightBlue,
        colors.yellow,
        colors.lime,
        colors.pink,
        colors.gray,
        colors.lightGray,
        colors.cyan,
        colors.purple,
        colors.blue,
        colors.brown,
        colors.green,
        colors.red,
        colors.black,
    }

local texture = {
    pixelbuffer={},-- [x:int][y:int] => {rgb={float,float,float},z:float,depth:float}
    bg={0,0,0}, -- {r,g,b}
    size={x=0,y=0},
    unique_colors = {}
}

local renderer = {
    texture,
    colorspace={},
    b=box.new(term.current())
}

function texture.fromFile(path) 
    local f = io.open(path,"r")
    local raw = f:read("*a")
    local pixelBuffer = textutils.unserialise(raw)
    f:close()
    print(pixelBuffer)
    return texture.new(pixelBuffer)
end

function texture.from255RGB(rgbArr)
    local pixelBuffer = {}
    for x=1,#rgbArr[1] do
        pixelBuffer[x] = {}
        for y=1,#rgbArr do
            local color = rgbArr[y][x]
            pixelBuffer[x][y] = {
                rgb={color.R/255,color.G/255,color.B/255}
            }
        end
    end
    return texture.new(pixelBuffer)
end

function texture.fromScreen()
    local x,y = term.getSize()
    return texture.window(2*x,3*y)
end

function texture.window(x,y,bg)
    bg = bg or {0,0,0}
    local pixelBuffer = {}
    for i=1,x do
        pixelBuffer[i] = {}
        for j=1,y do
            pixelBuffer[i][j] = {
                rgb={bg[1],bg[2],bg[3]},
                z=math.huge,
                depth=math.huge
            }
        end
    end
    return texture.new(pixelBuffer)
end

function texture.new(pixelbuffer)
    local o = deepcpy(texture)
    o.pixelbuffer = deepcpy(pixelbuffer)
    o.size = {x=#o.pixelbuffer,y=#o.pixelbuffer[1]}
    return o
end

function renderer.new(tex)
    local o = deepcpy(renderer)
    o.texture = tex or texture.fromScreen()
    o.texture:updateBuffer()
    o.colMap = {}
    return o
end

function texture:updateBuffer()
    for i = 1,self.size.x do
        self.pixelbuffer[i] = {}
        for j = 1,self.size.y do
            local bg = self.bg
            self.pixelbuffer[i][j] = {
                rgb={bg[1],bg[2],bg[3]},
                z=math.huge,
                depth=math.huge
            }
        end
    end
    return self
end

function texture:drawBuffer(buffer)
    for i=1,#buffer do
        local p = buffer[i]
        self:setPixel(p.x,p.y,{rgb=p.rgb})
    end
    return self
end

function renderer.zoom(u,v,px,py,scale,normalizeflag,repeatx,repeaty)
    px = px or 0
    py = py or 0
    scale = scale or 1
    u,v = (u+(px)*scale)/scale,(v+(py)*scale)/scale
    if normalizeflag then
        if repeatx then
            u = math.fmod(u,1)
            u = u<0 and 1+u or u
        else
            u = u>=1 and -1 or u<0 and -1 or u
        end
        if repeaty then
            v = math.fmod(v,1)
            v = v<0 and 1+v or v
        else
            v = v>=1 and -1 or v<0 and -1 or v
        end
    end
    return u,v
end

function texture:clear()
    --self.b:clear(self.toTermCol(self.bg))
    for i = 1,self.size.x do
        for j = 1,self.size.y do
            self.pixelbuffer[i][j] = {
                rgb=deepcpy(self.bg),
                z=math.huge,
                depth=math.huge,
                normal={x=0,y=0,z=0}
            }
        end
    end
end

function texture.transformuv(u,v,transform)
    local muv = Mat.from
    {
        {u},
        {v},
        {1}
    }
    muv = transform:matMul(muv)
    return muv.data[1][1],muv.data[2][1]
end

function texture:xinbound(x)
    return x>0 and x<=self.size.x
end

function texture:yinbound(y)
    return y>0 and y<=self.size.y
end

function texture:setPixel(x,y,pixel)
    x,y=math.floor(x),math.floor(y)
    local rgb = pixel.rgb
    local z = pixel.z or 0
    if self:xinbound(x) and self:yinbound(y) then
        self.pixelbuffer[x][y] = {
            rgb={rgb[1],rgb[2],rgb[3]},
            z=z,
            depth=x*x+y*y+z*z,
            normal=deepcpy(pixel.normal) or {x=0,y=0,z=0}
        }
    end
end

function texture:getUniqueColors(n)
    n=n or 1
    local rgbArr = {}
    for i=1,self.size.x,n do
        for j=1,self.size.y,n do
            local c = self:getPixel(i,j).rgb
            local contains = false
            for k=1,#rgbArr do
                if renderer.distance(rgbArr[k],c) < 0.01 then
                    contains = true
                    break
                end
            end
            if not contains then
                rgbArr[#rgbArr+1] = c
            end
        end
    end
    --print(textutils.serialise(rgbArr))
    return rgbArr
end

function texture:getPixel(x,y)
    x,y = math.floor(x),math.floor(y)
    x,y = math.min(self.size.x,math.max(1,x)),math.min(self.size.y,math.max(1,y))
    if self:xinbound(x) and self:yinbound(y) then
        return self.pixelbuffer[x][y]
    end
    return nil
end

function texture:fragshader(shaders)
    local x = self.size.x
    local y = self.size.y
    local ratio = (x/y)
    for u=0,1,1/(x) do
        for v=0,1,1/y do
            local pixel = self:getPixel(u*x+1,v*y+1)
            for _,shader in pairs(shaders) do
                pixel = shader(self,u,v,pixel)
            end
            self:setPixel(u*x+1,v*y+1,pixel)
        end
    end
end

function renderer:getLineBuffer(p1,p2,fn,flag)
    fn = fn or function()end
    local dx = p2.x-p1.x
    local dy = p2.y-p1.y
    local dz = p2.z-p1.z
    local pixels = {}
    if dx==0 and dy==0 then
        -- if not (self.texture:xinbound(p1.x) and self.texture:yinbound(p1.y)) then
        --     return pixels
        -- end
        local depth = p1.x*p1.x+p1.y*p1.y+p1.z*p1.z
        pixels[#pixels+1]=flag and {x=p1.x,y=p1.y,z=p1.z} or {
            rgb=fn(p1.x,p1.y,p1.z,depth),
            x=p1.x,
            y=p1.y,
            z=p1.z,
            depth=depth
        }
    elseif dy == 0 then
        local s = dx>0 and 1 or -1
        for x=p1.x,p2.x,s do
            -- if not (self.texture:xinbound(x) and self.texture:yinbound(p1.y)) then
            --     return pixels
            -- end
            local z = p1.z+dz*(x-p1.x)/dx
            local depth = x*x+p1.y*p1.y+z*z
            pixels[#pixels+1]=flag and {x=x,y=p1.y,z=z} or{
                rgb=fn(x,p1.y,z,depth),
                x=x,
                y=p1.y,
                z=z,
                depth=depth
            }
        end
    elseif dx == 0 then
        local s = dy>0 and 1 or -1
        for y=p1.y,p2.y,s do
            -- if not (self.texture:xinbound(p1.x) and self.texture:yinbound(y)) then
            --     return pixels
            -- end
            local z = p1.z-dz*(y-p1.y)/dy
            local depth = p1.x*p1.x+y*y+z*z
            pixels[#pixels+1]=flag and {x=p1.x,y=y,z=z} or{
                rgb=fn(p1.x,y,z,depth),
                x=p1.x,
                y=y,
                z=z,
                depth=depth
            }
        end
    else
        local a = dy/dx
        local b = p1.y-a*p1.x
        local s = dx>0 and 1 or -1
        local step = math.abs(1/a)<1 and s/math.abs(a) or s
        for x=p1.x,p2.x,step do
            local y = a*x+b
            -- if not (self.texture:xinbound(x) and self.texture:yinbound(y)) then
            --     return pixels
            -- end
            local z = p1.z+dz/2*(((x-p1.x)/dx)+((y-p1.y)/dy))
            local depth = math.sqrt(x*x+y*y+z*z)
            pixels[#pixels+1]=flag and {x=x,y=y,z=z} or {
                rgb=fn(x,y,z,depth),
                x=x,
                y=y,
                z=z,
                depth=depth
            }
        end
    end
    return pixels
end

local function appendtable(t1,t2)
    local t = deepcpy(t1)
    for i=1,#t2 do
        t[#t1+i] = deepcpy(t2[i])
    end
    return t
end

function renderer.normal(p1,p2,p3)
    local v1 = utils.vec(p1.x,p1.y,p1.z)
    local v2 = utils.vec(p2.x,p2.y,p2.z)
    local v3 = utils.vec(p3.x,p3.y,p3.z)
    local A = v2:sub(v1)
    local B = v3:sub(v2)
    return A:cross(B):normalize()
end

function renderer:getTriangleBuffer(p1,p2,p3,fn)
    local pixels = {}
    local pbuffer = {}
    local l1 = self:getLineBuffer(p1,p2,nil,true)
    local l2 = self:getLineBuffer(p1,p3,nil,true)
    local l3 = self:getLineBuffer(p2,p3,nil,true)
    pbuffer = appendtable(pbuffer,l1)
    pbuffer = appendtable(pbuffer,l2)
    pbuffer = appendtable(pbuffer,l3)
    for i=1,#pbuffer do
        local p = pbuffer[i]
        if p then
            pbuffer[i].x = math.floor(p.x+0.4999)
            pbuffer[i].y = math.floor(p.y+0.4999)
        end
    end
    local pery = {}
    local miny = pbuffer[1].y
    local maxy = pbuffer[1].y
    for i=1,#pbuffer do
        local p = pbuffer[i]
        if p then
            if p.y < miny then
                miny = p.y
            end
            if p.y > maxy then
                maxy = p.y
            end
        end
    end
    local offset = miny-1
    for i=1,maxy-offset do
        pery[i] = {}
    end
    for i=1,#pbuffer do
        local p = pbuffer[i]
        if p then
            local xs = pery[p.y-offset]
            xs[#xs+1] = p.x
        end
    end
    for i=1,#pery do
        local y = i+offset
        local xs = pery[i]
        if #xs > 0 then
            local minx = xs[1]
            local maxx = xs[1]
            for j=1,#xs do
                local p = xs[j]
                --print(j,p)
                if p < minx then
                    minx = p
                end
                if p > maxx then
                    maxx = p
                end
            end
            local xoffset = minx-1
            local n = self.normal(p1,p2,p3)
            for j=1,maxx-xoffset do
                local x = j+xoffset
                if self.texture:yinbound(y) and self.texture:xinbound(x) then
                    local z = (n.x*(x-p1.x)+n.y*(y-p1.y)-n.z*p1.z)/n.z
                    pixels[#pixels+1] = {rgb=fn(x,y,z,n),x=x,y=y,z=z}
                end
            end
        end
    end
    return pixels
end

function renderer.distance(col1,col2)
    return (col1[1]-col2[1])^2+(col1[2]-col2[2])^2+(col1[3]-col2[3])^2
end

function renderer.rectangleQuad(pos,width,height)
    local t1 = {
        {x = pos.x,y = pos.y+height,z = pos.z},
        {x = pos.x+width,y = pos.y+height,z = pos.z},
        {x = pos.x,y = pos.y,z = pos.z}
    }
    local t2 = {
        {x = pos.x+width,y = pos.y,z = pos.z},
        {x = pos.x,y = pos.y,z = pos.z},
        {x = pos.x+width,y = pos.y+height,z = pos.z},
    }
    return t1,t2
end

function renderer.quad(points)
    local triangles = {{}}
    local j = 1
    for i=1,#points do
        local p = points[i]
        triangles[j][#triangles[j]+1] = {x=p.x,y=p.y,z=p.z}
        if i%3 == 0 then
            j=j+1
            triangles[j] = {}
            triangles[j][#triangles[j]+1] = {x=p.x,y=p.y,z=p.z}
        end
    end
    local p = points[1]
    triangles[#triangles][#triangles[#triangles]+1] = {x=p.x,y=p.y,z=p.z}
    return triangles
end

function renderer.calcBaricentricCoords(a,b,c,p)
    local bary = utils.vec(0,0,0)
    local v0,v1,v2 = b:sub(a),c:sub(a),p:sub(a)
    local d00 = v0:dot(v0)
    local d01 = v0:dot(v1)
    local d11 = v1:dot(v1)
    local d20 = v2:dot(v0)
    local d21 = v2:dot(v1)
    local denom = d00*d11-d01*d01
    bary.z = (d11 * d20 - d01 * d21) / denom
    bary.x = (d00 * d21 - d01 * d20) / denom
    bary.y = 1 - bary.z - bary.x;
    -- local middle = a:add(b):add(c):mul(1/3)
    -- local ma = middle:sub(a)
    -- local lma = ma:len()
    -- --print(p)
    -- bary.x = 1-math.min(p:sub(a):len(),lma)/(lma)
    -- local mb = middle:sub(b)
    -- local lmb = mb:len()
    -- bary.y = 1-math.min(p:sub(b):len(),lmb)/(lmb)
    -- local mc = middle:sub(c)
    -- local lmc = mc:len()
    -- bary.z = 1-math.min(p:sub(c):len(),lmc)/(lmc)
    return bary
end

function renderer:toTermCol(col)
    local mind = math.huge
    local bestmatch = colors.black
    for i,c in pairs(self.colMap) do
        local ok = true
        for j=1,3 do
            if c[1][j] ~= col[j] then
                ok = false
                break
            end
        end
        if ok then
            return c[2]
        end
    end
    for i=1,#_colors do
        local v = {term.getPaletteColor(_colors[i])}
        --print(textutils.serialize(v))
        local d = renderer.distance(v,col)
        if d < mind then
            mind = d
            bestmatch = _colors[i]
        end
    end
    self.colMap[#self.colMap+1] = {col,bestmatch}
    return bestmatch
end

local function argmin(t)
    local minv = t[1]
    local mini = 1
    for i=1,#t do
        local v = t[i]
        if v < minv then
            minv = v
            mini = i
        end
    end
    return mini
end

local function normalize(t)
    local n = {}
    for i=1,3 do
        n[i] = math.max(0,math.min(t[i],1))
    end
    return n
end

function renderer.mix(col1,col2,k)
    k = k or 0.5
    local col = {}
    for i=1,3 do
        col[i] = (col1[i]*k+col2[i]*(1-k))
    end
    return col
end

function renderer.randomize(col,k)
    return normalize{col[1]+math.random()*k,col[2]+math.random()*k,col[3]+math.random()*k}
end

function renderer.meanColor(ct)
    local r = 0
    local g = 0
    local b = 0
    for _,c in pairs(ct) do
        --print(textutils.serialise(c))
        r = r + c[1]
        g = g + c[2]
        b = b + c[3]
    end
    return {r/#ct,g/#ct,b/#ct}
end

function renderer.kmeans(k,points,centroids,n)
    -- Initialization: choose k centroids (Forgy, Random Partition, etc.)

    -- Initialize clusters list
    local clusters = {}
    for i=1,k do
        clusters[i] = {}
    end
    --[ [] for _ in range(k)]
    
    -- Loop until convergence
    local maxt = n
    local t = 0
    local converged = false
    while not converged and t < maxt do
        -- Clear previous clusters
        for i=1,k do
            clusters[i] = {}
        end --[ [] for _ in range(k)]
    
        -- Assign each point to the "closest" centroid 
        for _,point in pairs(points) do
            local distances =  {} --[distance(point, centroid) for centroid in centroids]
            for j=1,k do
                distances[j] = renderer.distance(point,centroids[j])
            end
            local ci = argmin(distances)
            clusters[ci][#(clusters[ci])+1] = deepcpy(point)
        end
        -- Calculate new centroids
        --   (the standard implementation uses the mean of all points in a
        --     cluster to determine the new centroid)
        local function calculate_centroid(cluster)
            local centroid = {0,0,0}
            for _,point in pairs(cluster) do
                for i=1,3 do
                    centroid[i] = centroid[i]+point[i]
                end
            end
            for i=1,3 do
                centroid[i] = centroid[i]/#cluster
            end
            return centroid
        end
        
        local new_centroids = {}
        for i,cluster in pairs(clusters) do
            if #cluster == 0 then
                local col = renderer.randomize({0,0,0},1)
                cluster[1] = col
                points[#points+1] = {col[1],col[2],col[3]}
            end
                new_centroids[i] = calculate_centroid(cluster)
                --print(textutils.serialize(new_centroids[i]))
        end
        
        converged = true
        for i=1,k do
            for j=1,3 do
                if centroids[i][j] ~= new_centroids[i][j] then
                    converged = false
                    break
                end
            end
            if not converged then break end
        end
        centroids = deepcpy(new_centroids)
        --print(textutils.serialize(centroids))
        if converged then
            return centroids,clusters
        end
        t=t+1
    end
    return centroids
end

function renderer:resetPalette()
    for i=1,16 do
        term.setPaletteColor(_colors[i],term.nativePaletteColor(_colors[i]))
    end
end

function renderer:optimizeColors(n,k)
    local centroids = {} --[c1, c2, ..., ck]
    local uniqueColors = self.texture:getUniqueColors(k)
    uniqueColors[#uniqueColors+1] = {0,0,0}
    uniqueColors[#uniqueColors+1] = {1,1,1}
    local N = math.min(16,#uniqueColors)
    for i=1,N do
        centroids[i] = {}
        local col2 = {term.getPaletteColor(_colors[i])}
        centroids[i] = deepcpy(col2)
    end
    local newcolors = self.kmeans(N,uniqueColors,centroids,n)
    local dblack = {}
    for i=1,N do
        dblack[i] = self.distance(newcolors[i],{0,0,0})
    end
    local bi = argmin(dblack)
    newcolors[#newcolors],newcolors[bi] = newcolors[bi],newcolors[#newcolors]
    local dwhite = {}
    for i=1,N do
        dwhite[i] = self.distance(newcolors[i],{1,1,1})
    end
    local wi = argmin(dwhite)
    newcolors[1],newcolors[wi] = newcolors[wi],newcolors[1]
    self.colMap = {}
    for i=1,N do
        term.setPaletteColor(_colors[i],table.unpack(newcolors[i]))
    end
end

function renderer:render()
    for i = 1,self.texture.size.x do
        for j = 1,self.texture.size.y do
            local p = self.texture.pixelbuffer[i][j]
            -- local ok = true
            -- for i=1,3 do
            --     if p.rgb[i] ~= self.texture.bg[i] then
            --         ok = false
            --         break
            --     end
            -- end
            -- local col
            -- if ok then
            --     col = colors.black
            -- else
                local col = self:toTermCol(p.rgb)
            --end
            self.b:set_pixel(i,j,col)
        end
    end
    self.b:render()
end

return {renderer=renderer,texture=texture}