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

local mousepos = nil
local gravity = 50
local fps = 20

local function renderBody(color,colorColliding)
    return function(self)
        local prev = #self.currentPoints
        for i,point in pairs(self.points) do
            local A = self.currentPoints[prev]
            local B = self.currentPoints[i]
            r.texture:drawBuffer(r:getLineBuffer(vec(A.x,A.y,0),vec(B.x,B.y,0),
            function()
                return self.colliding and colorColliding or color
            end))
            local com = self.com+self.pos
            r.texture:setPixel(com.x,com.y,{rgb={1,1,0}})
            prev = i
        end
        local target = mousepos or vec2(r.texture.size.x/2,r.texture.size.y/2)
        local p = vec2(0,0)
        p=self:transform(p)
        r.texture:drawBuffer(r:getLineBuffer(vec(p.x,p.y,0),vec(target.x,target.y,0),
        function()
            return {0.8,0,0.8}
        end))
        if self.thrusters then
            for _,thruster in pairs(self.thrusters) do
                local p1 = self:transform(thruster.pos)
                local p2 = self:transform(thruster.pos-10*(thruster.thrust/self.maxThrust))
                r.texture:drawBuffer(r:getLineBuffer(vec(p1.x,p1.y,0),vec(p2.x,p2.y,0),
                function()
                    return {0,1,1}
                end))
            end
            for _,thruster in pairs(self.thrusters) do
                local p1 = self:transform(thruster.pos)
                r.texture:setPixel(p1.x,p1.y,{rgb={1,0,0}})
            end
        end
    end
end

local function interpolate(a,b,p)
    return a*p+b*(1-p)
end

local drone = body.new{
            points={vec2(0,0),vec2(10,0),vec2(10,30),vec2(0,30)},
            render=renderBody({1,1,1},{1,0,0}),
            pos=vec2(r.texture.size.x/2,r.texture.size.y/2),
            mass=10,
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
                    local targetVel = (target-self.pos)/dt-self.vel/dt
                    local targetOmega = (targetAng-self.rot)/dt-self.omega/dt
                    local newThrusts = {}
                    for i=1,#self.thrusters do
                        newThrusts[i] = vec2(0,0)
                    end
                    local k1 = 10/(#self.thrusters)
                    local k2 = 50/(#self.thrusters)
                    local maxi = math.max(800/(#self.thrusters),100)
                    local epslin = 0.01
                    local epsang = 0.0001
                    local dolin = true
                    local doang = true

                    local function dcostLin(targetVel)
                        local thrustSum = 0--vec2(0,-gravity)
                        for _,thrust in pairs(newThrusts) do
                            thrustSum = thrustSum+thrust
                        end
                        return 2*(self.vel+dt/self.mass*(self.force+thrustSum)-targetVel)*dt/self.mass
                    end

                    local function dcostAng(targetOme,pos)
                        local r = pos:rotate(self.rot)
                        local thrustSum = 0
                        for i,thrust in pairs(newThrusts) do
                            thrustSum = thrustSum+cross(self.thrusters[i].pos:rotate(self.rot),thrust)
                        end
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
                            for i,thrust in pairs(newThrusts) do
                                newThrusts[i] = (thrust-slope*k1)
                            end
                        elseif doang then
                            local slopeMean = 0
                            for i,thrust in pairs(newThrusts) do
                                local slope = dcostAng(targetOmega,self.thrusters[i].pos)
                                slopeMean = slopeMean + slope
                                newThrusts[i] = (thrust-slope*k2)
                            end
                            slopeMean = slopeMean/#newThrusts
                            if math.abs(slopeMean.x) < epsang and math.abs(slopeMean.y) < epsang then
                                doang = false
                            end
                        end
                    end

                    for i,thruster in pairs(self.thrusters) do
                        thruster.thrust = (thruster.thrust*2+self:invtransform(newThrusts[i]))/3
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
local targetAng = 0

local bh = handler.new{
    fps=fps,
    maxFrameT=0.5,
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
    render_=function(self)r:render()end,
    onPhysicsTick=function(self,dt)
        tsum = tsum+dt
        for _,b in pairs(self.bodies) do
            b.colliding = false
            b.force.y = b.force.y+b.mass*gravity
            if b.thrusters then
                if tsum > 0.05 then
                    local target = mousepos or vec2(r.texture.size.x/2,r.texture.size.y/2)
                    b:calcThrusterForces(target,targetAng,tsum)
                    tsum = 0
                end
                b:applyThrusterForces()
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

local state = "edit"

while true do
    if state == "edit" then
        local key = nil
        while key ~= "space" do
            r.texture:clear()
            drone.rot = targetAng
            for _,thruster in pairs(drone.thrusters) do
                thruster.thrust = drone:invtransform(vec2(0,-drone.maxThrust))
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
                local pos = vec2(2*event[3],3*event[4])
                if bh.getCollisionDepth(drone,{normals={},project=function(self,dir)return pos:dot(dir),pos:dot(dir) end}) then
                    local ok = true
                    for i,thruster in pairs(drone.thrusters) do
                        if #(drone:transform(thruster.pos)-pos) <= 1 then
                            ok = false
                        end
                    end
                    if ok then
                        drone.thrusters[#drone.thrusters+1] = {pos=drone:invtransform(pos),thrust=vec2(0,0)}
                    end
                end
            end
            r:render()
            term.setCursorPos(1,1)
            term.setBackgroundColor(colors.white)
            term.setTextColor(colors.black)
            term.write("target angle: "..math.floor(math.deg(targetAng)).."'")
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
                        mousepos = vec2(2*event[3],3*event[4])
                    end
                end
            end,
            function()
                bh:run()
            end
        )
    end
end