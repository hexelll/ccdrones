local fysics = require"ccfisiks.ccfisiks"
local body = fysics.rigidbody2D
local handler = fysics.rigidbody2Dhandler
local vec2package = require"libs.vec2"
local vec2=vec2package.vec2
local vec2_=vec2package.vec2_
local cross=vec2_.cross
package.path=";/?.lua"
local rendererpackage = require"ccshade.renderer.renderer"
local renderer = rendererpackage.renderer
local texture = rendererpackage.texture
shell.setDir("/")
package.path=";/?.lua"
local deepcpy = require"ccshade.renderer.libs.deepcpy"
local m = require"ccshade.renderer.libs.Mat"
local utils = require"ccshade.renderer.libs.utils"

local vec = utils.vec

local r = renderer.new()
r:resetPalette()
r.texture.bg = {0,0.5,0.5}

local mousepos = nil
local gravity = 50
local fps = 20

local posQueue = {}
local posQueueLen = fps
local particles = {}
local particleAmount = 2
local state = "edit"

local function mkbutton(text,pos,width,height,color)
    local button = {}
    button.pos = pos
    button.width = width
    button.height = height
    button.text = text
    button.color = color
    function button:render()
        for i=1,width do
            for j=1,height do
                r.texture:setPixel(i+pos.x,j+pos.y,{rgb=color})
            end
        end
    end
    function button:renderText()
        term.setBackgroundColor(r.toTermCol(self.color))
        term.setTextColor(r.toTermCol({1-self.color[1],1-self.color[2],1-self.color[3]}))
        term.setCursorPos(math.ceil(self.pos.x/2+self.width/4-#self.text/2+0.4999),math.ceil(self.pos.y/3+self.height/6+0.4999)-1)
        term.write(self.text)
    end
    function button:isIn(clickpos)
        return clickpos.x > self.pos.x and clickpos.x < self.pos.x+self.width and clickpos.y > self.pos.y and clickpos.y < self.pos.y+self.height+1
    end
    return button
end

local resetButton=mkbutton("clear thrusters",vec2(r.texture.size.x-35,1),34,8,{1,1,1})
local turnRight=mkbutton("\24",vec2(8,6),5,5,{1,1,1})
local turnLeft=mkbutton("\25",vec2(1,6),5,5,{1,1,1})
local s = "Start Sim"
local startSim=mkbutton(s,vec2(r.texture.size.x/2-#s-1,1),#s*2+2,8,{1,1,1})
s = "Stop Sim"
local stopSim=mkbutton(s,vec2(r.texture.size.x/2-#s-1,1),#s*2+2,8,{1,0,0})

local function renderBody(color,colorColliding)
    return function(self)
        local prev = #self.currentPoints
        -- for i,point in pairs(self.points) do
        --     local A = self.currentPoints[prev]
        --     local B = self.currentPoints[i]
        --     r.texture:drawBuffer(r:getLineBuffer(vec(A.x,A.y,0),vec(B.x,B.y,0),
        --     function()
        --         return self.colliding and colorColliding or color
        --     end))
        --     local com = self.com+self.pos
        --     r.texture:setPixel(com.x,com.y,{rgb={0.6,0.5,0}})
        --     prev = i
        -- end
        local c = 1
        for k,points in pairs(self.mesh) do
            local points3 = {}
            for i=c,c+#points.data-1 do
                local p = self.currentPoints[i]
                points3[i-c+1] = vec(p.x,p.y,0)
            end
            c=c+#points.data
            local ts = r.quad(points3)
            local t1 = ts[1]
            local t2 = ts[2]
            local linecol1 = function(x,y,z,n)
                local vec  = utils.vec3.new()
                local uvw = r.calcBaricentricCoords(vec.from(t1[1]),vec.from(t1[2]),vec.from(t1[3]),utils.vec(x,y,z))
                local u = 1-((((1-uvw.z)-uvw.x)))
                local v = ((1-uvw.z)-uvw.y)
                v=math.floor(v*4)/4
                return {0.5*math.max(0.2,1-v),0.5*math.max(0.2,1-v),0.5*math.max(0.2,1-v)}
                --return {uvw.x,uvw.y,uvw.z}
            end
            r.texture:drawBuffer(r:getTriangleBuffer(t1[1],t1[2],t1[3],linecol1))
            local linecol2 = function(x,y,z,n)
                local vec  = utils.vec3.new()
                local uvw = r.calcBaricentricCoords(vec.from(t2[1]),vec.from(t2[2]),vec.from(t2[3]),utils.vec(x,y,z))
                local u = ((1-uvw.z)-uvw.x)
                local v = 1-(((1-uvw.z)-uvw.y))
                v=math.floor(v*4)/4
                return {0.5*math.max(0.2,1-v),0.5*math.max(0.2,1-v),0.5*math.max(0.2,1-v)}
                --return {uvw.x,uvw.y,uvw.z}
            end
            r.texture:drawBuffer(r:getTriangleBuffer(t2[1],t2[2],t2[3],linecol2))
        end
        local target = mousepos or vec2(r.texture.size.x/2,r.texture.size.y/2)
        local p = vec2(0,0)
        p=self:transform(p)
        r.texture:drawBuffer(r:getLineBuffer(vec(p.x,p.y,0),vec(target.x,target.y,0),
        function()
            return {1,1,1}
        end))
        if self.thrusters then
            -- for _,thruster in pairs(self.thrusters) do
            --     local p1 = self:transform(thruster.pos)
            --     local p2 = self:transform(thruster.pos-10*(thruster.thrust/self.maxThrust))
            --     r.texture:drawBuffer(r:getLineBuffer(vec(p1.x,p1.y,0),vec(p2.x,p2.y,0),
            --     function(x,y,z)
            --         local k = math.max(0,math.min(1,1-#(vec2(x,y)-p1)/#(p2-p1)))
            --         return {k,k,k}
            --     end))
            -- end
            if state == "edit" then
                for _,thruster in pairs(self.thrusters) do
                    local p1 = self:transform(thruster.pos)
                    r.texture:setPixel(p1.x,p1.y,{rgb={1,1,1}})
                    r.texture:setPixel(p1.x+1,p1.y,{rgb={1,1,1}})
                    r.texture:setPixel(p1.x-1,p1.y,{rgb={1,1,1}})
                    r.texture:setPixel(p1.x,p1.y+1,{rgb={1,1,1}})
                    r.texture:setPixel(p1.x,p1.y-1,{rgb={1,1,1}})
                end
            end
            for _,particle in pairs(particles) do
                local k = math.max(0,math.min(10*math.sqrt(#particle.vel),#particle.initVel)/#particle.initVel)
                r.texture:setPixel(particle.pos.x,particle.pos.y,{rgb=r.mix({0.4,0.1,0},{0.8,0.8,0.8},k)})
            end
        end
        for i,point in pairs(posQueue) do
            local k = math.max(1-(i/#posQueue)^2,0)
            r.texture:setPixel(point.x,point.y,{rgb=r.mix({0.3,1,1},r.texture.bg,k)})
        end
    end
end

local function interpolate(a,b,p)
    return a*p+b*(1-p)
end

local drone = body.new{
            mesh={
                {data={vec2(0,0),vec2(20,0),vec2(20,30),vec2(0,30)},mass=10},
                {data={vec2(20,5),vec2(30,5),vec2(30,25),vec2(20,25)},mass=10},
                {data={vec2(30,0),vec2(50,0),vec2(50,30),vec2(30,30)},mass=10}},
            render=renderBody({1,0.7,0.5},{1,0,0}),
            pos=vec2(r.texture.size.x/2,r.texture.size.y/2),
            rot=0,
            restitution=0.5,
            thrusters={},
            maxThrust=800,
            applyThrusterForces=function(self)
                for _,thruster in pairs(self.thrusters) do
                    self:applyForceAtPoint(thruster.pos,self:transform(thruster.thrust))
                end
                return self
            end,
            calcThrusterForces=function(self,target,targetAng,dt)
                if #self.thrusters > 0 then
                    local targetVel = (self.mass*(target-self.pos-self.vel)/dt)
                    local targetOmega = (self.mmoi*(targetAng-self.rot-self.omega)/dt)
                    local newThrusts = {}
                    for i=1,#self.thrusters do
                        newThrusts[i] = ((targetVel-self.force)/#self.thrusters)/(#self.thrusters[i].pos)
                    end
                    local n = math.max(6,math.ceil(gravity*self.mass/self.maxThrust))
                    --print(n)
                    n = math.min(n,#newThrusts)
                    if n < #self.thrusters then
                        for i=1,n do
                            local dir = self:transform(vec2(0,-1):rotate((i-1)/(n-1)*2*math.pi))
                            local is = {}
                            local max = 1
                            local maxval = -1
                            for i=2,#newThrusts do
                                local d = self.thrusters[i].pos:dot(dir)
                                if d>maxval then
                                    maxval = d
                                    max = i
                                end
                            end
                            is[#is+1] = max
                            for i,j in pairs(is) do
                                self.thrusters[j],self.thrusters[i] = self.thrusters[i],self.thrusters[j]
                                newThrusts[j],newThrusts[i]=newThrusts[i],newThrusts[j]
                            end
                        end
                    end
                    local k1 = 800/(#self.thrusters)
                    local k2 = 800/(#self.thrusters)
                    local maxi = math.max(1000/(#self.thrusters),100)
                    local epslin = 0.01
                    local epsang = 0.001
                    local dolin = true
                    local doang = true

                    local function thrustSum()
                        local thrustSum = 0
                        for i=1,n do
                            thrustSum = thrustSum+newThrusts[i]
                        end
                        return thrustSum
                    end
                    
                    local function crossThrustSum()
                        local thrustSum = 0
                        for i=1,n do
                            thrustSum = thrustSum+cross(self.thrusters[i].pos:rotate(self.rot),newThrusts[i])
                        end
                        return thrustSum
                    end

                    local function dcostLin(targetVel)
                        local thrustSum = thrustSum()
                        return 2*(self.vel+dt/self.mass*(self.force+thrustSum)-targetVel)*dt/self.mass
                    end

                    local function dcostAng(targetOme,pos)
                        local r = pos:rotate(self.rot)
                        local thrustSum = crossThrustSum()
                        local k = 2*(self.omega+dt/self.mmoi*(self.torque+thrustSum)-targetOme)*dt/self.mmoi
                        return vec2(k*-r.y,k*r.x)
                    end
                    for i=1,maxi do
                        if not dolin and not doang then
                            break
                        end
                        if i%2 == 0 and dolin then
                            local slope = dcostLin(targetVel)
                            if math.abs(slope.x) < epslin and math.abs(slope.y) < epslin then
                                dolin = false
                            end
                            for i=1,n do
                                newThrusts[i] = (newThrusts[i]-slope*k1)
                            end
                            local nslope = dcostLin(targetVel)
                            if (nslope.x > 0 and slope.x < 0) or (nslope.x < 0 and slope.x > 0) then
                                k1 = k1*0.8
                            end
                        elseif doang then
                            local slopeMean = 0
                            for i=1,n do
                                local slope = dcostAng(targetOmega,self.thrusters[i].pos)
                                slopeMean = slopeMean + slope
                                newThrusts[i] = (newThrusts[i]-slope*k2)
                            end
                            slopeMean = slopeMean/n
                            if math.abs(slopeMean.x) < epsang and math.abs(slopeMean.y) < epsang then
                                doang = false
                            end
                            local nslopeMean = 0
                            for i=1,n do
                                local slope = dcostAng(targetOmega,self.thrusters[i].pos)
                                nslopeMean = nslopeMean + slope
                            end
                            local nslope = nslopeMean/n
                            if (nslope.x > 0 and slopeMean.x < 0) or (nslope.x < 0 and slopeMean.x > 0) then
                                k2 = k2*0.8
                            end
                        end
                    end

                    for i,thruster in pairs(self.thrusters) do
                        thruster.thrust = (thruster.thrust*4+(newThrusts[i]):rotate(-self.rot)*self.mass)/5
                        thruster.thrust = thruster.thrust:clampLength(self.maxThrust)
                    end
                end
                return self
            end,
            resetThrusterForces=function(self)
                for _,thruster in pairs(self.thrusters) do
                    thruster.thrust = vec2(0,-self.maxThrust)
                end
                return self
            end
        }

local tsum = 0
local tsumbis = 0
local targetAng = 0

local bh = handler.new{
    fps=fps,
    maxFrameT=0.8,
    bodies={
        drone
        -- ,
        -- body.new{
        --     points={vec2(0,0),vec2(50,0),vec2(50,30),vec2(0,30)},
        --     render=renderPolygon({1,0.5,1},{1,1,0}),
        --     pos=vec2(50,60),
        --     mass=10,
        --     restitution=0,
        --     immovable=true,
        -- }
    },
    drag=0.95,
    clear_=function(self)r.texture:clear()end,
    render_=function(self,dt)
        if state == "sim" then
            stopSim:render()
        end
        r:optimizeColors(20)
        r:render()
        if state == "sim" then
            stopSim:renderText()
        end
    end,
    onPhysicsTick=function(self,dt)
        tsum = tsum+dt
        for _,b in pairs(self.bodies) do
            b.colliding = false
            b.force.y = b.force.y+b.mass*gravity
            if b.thrusters then
                if tsum > 0.03 then
                    local target = mousepos or vec2(r.texture.size.x/2,r.texture.size.y/2)
                    b:calcThrusterForces(target,targetAng,tsum)
                    tsum = 0
                end
                b:applyThrusterForces()
            end
            posQueue[#posQueue+1] = posQueue[#posQueue]
            for i=#posQueue,2,-1 do
                posQueue[i]=posQueue[i-1]
            end
            if #posQueue > posQueueLen then
                for i=posQueueLen,#posQueue do
                    posQueue[i] = nil
                end
            end
            posQueue[1] = b.pos
            for _,thruster in pairs(b.thrusters) do
                for i =1,particleAmount do
                    local v = -100*thruster.thrust/b.maxThrust+vec2(math.random()*5,math.random()*5)
                    particles[#particles+1] = {
                        pos=b:transform(thruster.pos),
                        vel=v,
                        initVel=v
                    }
                end
            end
            local offset = 0
            for i,particle in pairs(particles) do
                i=i-offset
                particle.vel = particle.vel*0.8
                particle.pos = particle.pos+particle.vel*dt
                if #particle.vel < 0.1 then
                    offset = offset+1
                    for j=i,#particles do
                        particles[j]=particles[j+1]
                    end
                end
            end
        end
        local collisions = self:collisions()
        for _,col in pairs(collisions) do
            col[1].colliding = true
            col[2].colliding = true
        end
    end,
    -- onCollision=function(self,A,B,normal,depth,contained,flip,impulse)
    --     local b = flip and A or B
    --     local prev = #b.points
    --     for i,n in pairs(b.normals) do
    --         if n.x == normal.x and n.y==normal.y then
    --             local middle = (b.points[i]+b.points[prev])/2
    --             local pn = middle+normal*20
    --             local pi = middle+impulse*10
    --             middle = b:transform(middle)
    --             pn = b:transform(pn)
    --             pi = b:transform(pi)
    --             r.texture:drawBuffer(r:getLineBuffer(vec(middle.x,middle.y,0),vec(pn.x,pn.y,0),function()
    --                 return {0,1,1}
    --             end))
    --             -- r.texture:drawBuffer(r:getLineBuffer(vec(middle.x,middle.y,0),vec(pi.x,pi.y,0),function()
    --             --     return {1,0,1}
    --             -- end))
    --         end
    --         prev = i
    --     end
    -- end
}

while true do
    if state == "edit" then
        local key = nil
        while key ~= "space" do
            posQueue = {}
            particles = {}
            mousepos = nil
            r.texture:clear()
            drone.rot = targetAng
            for _,thruster in pairs(drone.thrusters) do
                thruster.thrust = drone:invtransform(vec2(0,0))
            end
            drone
            :updateCurrentPoints()
            :render()
            local event = {os.pullEvent()}
            if event[1] == "key" then
                key = keys.getName(event[2])
                if key == "right" then
                    drone.rot = drone.rot + 0.1
                    targetAng = drone.rot
                end
                if key == "left" then
                    drone.rot = drone.rot - 0.1
                    targetAng = drone.rot
                end
            end
            if event[1] == "mouse_click" then
                local pos = vec2(2*event[3],3*event[4]-1)
                if resetButton:isIn(pos) then
                    drone.thrusters = {}
                elseif turnRight:isIn(pos) then
                    drone.rot = drone.rot + 0.1
                    targetAng = drone.rot
                elseif turnLeft:isIn(pos) then
                    drone.rot = drone.rot - 0.1
                    targetAng = drone.rot
                elseif startSim:isIn(pos) then
                    break
                elseif bh.getCollisionDepth(drone,{normals={},project=function(self,dir)return pos:dot(dir),pos:dot(dir) end}) then
                    local ok = true
                    for i,thruster in pairs(drone.thrusters) do
                        if #(drone:transform(thruster.pos)-pos) <= 2 then
                            ok = false
                        end
                    end
                    if ok then
                        drone.thrusters[#drone.thrusters+1] = {pos=drone:invtransform(pos),thrust=vec2(0,0)}
                    end
                end
            end
            resetButton:render()
            turnRight:render()
            turnLeft:render()
            startSim:render()
            bh:render_(0.1)
            term.setCursorPos(1,1)
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
            term.write("target angle: "..math.floor(math.deg(targetAng)).."'")
            resetButton:renderText()
            turnRight:renderText()
            turnLeft:renderText()
            startSim:renderText()
        end
        state = "sim"
    elseif state == "sim" then
        parallel.waitForAny(
            function()
                while true do
                    local event = {os.pullEvent()}
                    if event[1] == "key" then
                        key = keys.getName(event[2])
                        if key == "space" then
                            drone.pos = vec2(r.texture.size.x/2,r.texture.size.y/2)
                            drone.rot = 0
                            drone.vel = vec2(0,0)
                            drone.omega = 0
                            state = "edit"
                            drone:resetThrusterForces()
                            break
                        end
                    end
                    if event[1] == "mouse_click" then
                        local pos = vec2(2*event[3],3*event[4])
                        if stopSim:isIn(pos) then
                            drone.pos = vec2(r.texture.size.x/2,r.texture.size.y/2)
                            drone.rot = 0
                            drone.vel = vec2(0,0)
                            drone.omega = 0
                            state = "edit"
                            drone:resetThrusterForces()
                            break
                        else
                            mousepos = pos
                        end
                    end
                end
            end,
            function()
                bh:run()
            end
        )
    end
end
