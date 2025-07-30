package.path =";/ccfisiks/?.lua"
local utils = require"libs.utils"
local vec2package = require"libs.vec2"
local vec2=vec2package.vec2
local vec2_=vec2package.vec2_
local cross=vec2_.cross
local m = require "libs.Mat"
local deepcpy = require "libs.deepcpy"

local rigidbody2D = {
    com = vec2(0,0),
    pos = vec2(0,0),
    vel = vec2(0,0),
    force = vec2(0,0),
    rot = 0,
    omega = 0,
    torque = 0,
    mass=1,
    restitution=1,
    com=vec2(0,0),
    mmoi=1,
    mesh = nil,
    vertices = {},
    normals = {},
    currentPoints = {},
    radius = 0,
    immovable=false,
    onCollision = function()end,
    render = function()end
}

function rigidbody2D.new(params)
    local o = {}
    for k,v in pairs(params) do
        o[k] = v
    end
    setmetatable(o,{
        __index=function(_,k)
            return rigidbody2D[k]
        end
    })
    o:computeConstants()
    :calcVertices()
    :calcNormals()
    return o
end

--todo
--triangulation for accurate copm and mmoi
function rigidbody2D:computeConstants()
    local com = vec2()
    local massSum = 0
    for _,points in pairs(self.mesh) do
        local subcom = vec2()
        for _,point in pairs(points.data) do
            subcom = subcom+point
        end
        subcom = subcom/#points.data
        com=com+subcom*points.mass
        massSum = massSum + points.mass
    end
    com = com/massSum
    self.mass = massSum
    self.com = com
    --print(com)
    if self.com ~= vec2(0,0) then
        for _,points in pairs(self.mesh) do 
            for i,p in pairs(points.data) do
                points.data[i] = p-self.com
            end
        end
    end
    self.com = vec2(0,0)
    local mmoi = 0
    for _,points in pairs(self.mesh) do
        local submmoi = 0
        for _,point in pairs(points.data) do
            submmoi = submmoi+#point
        end
        submmoi = submmoi/#points.data*points.mass
        mmoi = mmoi+submmoi
    end
    self.mmoi = mmoi*10
    --print(mmoi)
    return self
end

function rigidbody2D:calcVertices()
    self.vertices = {}
    for _,points in pairs(self.mesh) do
        local l = #points.data
        local prev = l
        for i=1,l do
            local a = points.data[prev]
            local b = points.data[i]
            self.vertices[#self.vertices+1] = b-a
            prev = i
        end
    end
    return self
end


function rigidbody2D:calcNormals()
    self.normals = {}
    local prev = #self.vertices
    for i,vert in pairs(self.vertices) do
        self.normals[i] = vert:normal()
        self.normals[i] = -self.normals[i]/#self.normals[i]
    end
    return self
end

--deprecated
function rigidbody2D:calcRadius()
    local radius = 0
    for _,point in pairs(self.points) do
        local d = #point
        if d > radius then
            radius = d
        end
    end
    self.radius = radius
    return self
end

--deprecated
function rigidbody2D:project(dir)
    local max = -math.huge
    local min = math.huge
    for _,point in pairs(self.currentPoints) do
        local p = point:dot(dir)
        max = p>max and p or max
        min = p<min and p or min
    end
    return min,max
end

function rigidbody2D:applyForceAtPoint(p,force)
    if p.x and p.y and force.x and force.y then
        local r = p:rotate(self.rot)
        local torque_step = cross(r,force)
        self.torque = self.torque+torque_step
        self.force = (self.force)+force
    end
    return self
end

function rigidbody2D:integrate(dt)
    if not self.immovable then
        self.vel = self.vel+self.force/self.mass*dt
        self.pos = self.pos+self.vel*dt
        self.omega = self.omega+self.torque/self.mmoi*dt
        self.rot = self.rot+self.omega*dt
        self.force = vec2(0,0)
        self.torque = 0
    end
    return self
end

function rigidbody2D:updateCurrentPoints()
    self.currentPoints = {}
    local c = 1
    for k,points in pairs(self.mesh) do
        for i,point in pairs(points.data) do
            self.currentPoints[c+i-1] = self:transform(point)
        end
        c=c+#points.data
    end
    return self
end

--deprecated
function rigidbody2D:getSupport(dir)
    local bestProj = -math.huge
    local bestVert = vec2()
    local vertices = self.vertices
    for i,vert in pairs(vertices) do 
        local proj = vert:dot(dir)
        if proj > bestProj then
            bestVert = vert
            bestProj = proj
        end
    end
    return bestVert
end

function rigidbody2D:transform(v)
    return v:rotate(self.rot)+self.pos
end

function rigidbody2D:invtransform(v)
    return (v-self.pos):rotate(-self.rot)
end

--deprecated
function rigidbody2D:applyImpulse(impulse,contactVec)
    if not self.immovable then
    self.vel = self.vel+impulse/self.mass

    self:applyForceAtPoint(contactVec,impulse)
    end
    return self
end

local rigidbody2Dhandler = {
    bodies = {},
    fps = 30,
    drag = 1,
    maxFrameT = 0.1,
    clear_=function()end,
    render_=function()end,
    onCollision=function()end,
    onPhysicsTick=function()end
}


function rigidbody2Dhandler.new(params)
    local o = {}
    for k,v in pairs(params) do
        o[k] = v
    end
    setmetatable(o,{
        __index=function(_,k)
            return rigidbody2Dhandler[k]
        end
    })
    return o
end

function rigidbody2Dhandler:integrate(dt)
    for _,body in pairs(self.bodies) do
        body:integrate(dt):updateCurrentPoints()
        --body.vel = body.vel*(self.drag)
        --body.omega = body.omega*(self.drag)
        body.force = vec2(0,0)
        body.torque = 0
    end
    return self
end

--deprecated
function rigidbody2Dhandler:possibleCollisions()
    local possibleCollisions = {}
    local map = {}
    for i,A in pairs(self.bodies) do
        for j,B in pairs(self.bodies) do
            if i ~= j then
                if #(A.pos-B.pos) < A.radius then
                    local ok = true
                    for _,c in pairs(map) do
                        if (c[1] == i and c[2] == j) or (c[1] == j and c[2] == i) then
                            ok = false
                            break
                        end
                    end
                    if ok then
                        map[#map+1] = {i,j}
                        possibleCollisions[#possibleCollisions+1] = {A,B}
                    end
                end
            end
        end
    end
    --print(#possibleCollisions)
    return possibleCollisions
end

function rigidbody2Dhandler.getCollisionDepth(A,B)
    local mindepth = math.huge
    local minn = nil
    local contained = false
    local normals = {}
    local flip = false
    local ni = nil
    for _,n in pairs(A.normals) do
        normals[#normals+1] = n:cpy()
    end
    local l = #normals
    for _,n in pairs(B.normals) do
        normals[#normals+1] = n:cpy()
    end
    --print("start")
    for i,n in pairs(normals) do
        if i > l then
            n=n:rotate(B.rot)
        else
            n=n:rotate(A.rot)
        end
        local min1,max1 = A:project(n)
        local min2,max2 = B:project(n)
        local f = i>l
        if min1 > min2 then
            min1,min2=min2,min1
            max1,max2=max2,max1
            f = not f
        end
        local o1 = {min1-min2,min1-max2,max1-min2,max1-max2}
        local o2 = {}
        for i,o in pairs(o1) do
            if o > 0 then
                o2[#o2+1]=o
            end
        end
        if #o2 > 0 then
            local overlap
            if #o2 == 2 then
                contained = true
                overlap = math.max(table.unpack(o2))
            else
                overlap = math.min(table.unpack(o2))
            end
            if overlap < mindepth then
                mindepth = overlap
                minn = n
                ni = i
                ni = i>l and ni-l or ni
                contained = false
                flip = f
            end
        else
            minn = nil
            break
        end
    end
    --print("end")
    --print(minn,flip)
    return minn,ni,mindepth,contained,flip
end

--deprecated
function rigidbody2Dhandler:collisions()
    local possibleCollisions = self:possibleCollisions()
    local collisions = {}
    for _,col in pairs(possibleCollisions) do
        local A,B = col[1],col[2]
        local normal,normali,depth,contained,flip = self.getCollisionDepth(A,B)
        if normal then
            collisions[#collisions+1] = {A,B,normal,normali,depth,contained,flip}
        end
    end
    return collisions
end

--deprecated
function rigidbody2Dhandler:correctPosition(A,B,n,d)
    local percent = 0.8
    local slop = 0
    local correction = (math.max(d-slop,0)/(1/A.mass + 1/B.mass)*percent)*n/#n/2
    if not A.immovable then
        A.pos = A.pos-correction/A.mass
    end
    if not B.immovable then
        B.pos = B.pos+correction/B.mass
    end
end

--deprecated
function rigidbody2Dhandler:resolveCollisions()
    local collisions = self:collisions()
    
    for i,col in pairs(collisions) do 
        local A,B,normal,normali,depth,contained,flip = table.unpack(col)
        normal = flip and -normal or normal
        normal.y = normal.y
        local k = -(1+math.max(A.restitution,B.restitution))
        local v = B.vel-A.vel
        local vn = normal:dot(v)
        if vn < 0 then
            local j = vn*k
            local msum = 0
            if not A.immovable then
                msum = msum+1/A.mass
            end
            if not B.immovable then
                msum = msum+1/B.mass
            end
            j=j/msum
            local impulse = normal*j
            self:onCollision(A,B,normal,depth,contained,flip,impulse)
            local contact = vec2(0,0)
            local b = flip and B or A
            local prev = #b.points
            for i,n in pairs(b.normals) do
                if i == normali then
                    contact = (b.points[i]+b.points[prev])/2
                    --print(contact)
                    --sleep(0.1)
                end
                prev = i
            end
            
            A:applyImpulse(-impulse,vec2(0,0))
            B:applyImpulse(impulse,vec2(0,0))
        end
        self:correctPosition(A,B,normal,depth)
    end
    return self
end

function rigidbody2Dhandler:render()
    for _,body in pairs(self.bodies) do
        body:render()
    end
    return self
end

function rigidbody2Dhandler:run()
    local taccumulator = 0
    local dt = 1/self.fps
    self:integrate(dt)
    local lastT = os.clock()
    while true do
        self:clear_()
        local currentT = os.clock()
        taccumulator = taccumulator+currentT-lastT
        lastT = currentT
        taccumulator = math.min(self.maxFrameT,taccumulator)
        while taccumulator > dt do
            self:onPhysicsTick(dt)
            self:integrate(dt)
            self:resolveCollisions()
            
            taccumulator = taccumulator-dt
        end
        self:render()
        self:render_(currentT-lastT)
        sleep()
    end
end

return {
    rigidbody2D = rigidbody2D,
    rigidbody2Dhandler = rigidbody2Dhandler
}