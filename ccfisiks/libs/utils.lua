local utils = {}
local p = peripheral

function utils.Class(table,name)
    return {
        new = function(o)
            o = o or {}
            setmetatable(o,{
                __index = function(_,i)
                    return table[i]
                end,
                __tostring = function()
                    return '('..o.x..','..o.y..','..o.z..')'
                end
            })
            return o
        end,
        name = name
    }
end

function utils.amin(t)
    local min = t[1]
    local mini = 1
    for i,n in pairs(t) do
        if math.abs(n) < math.abs(min) then
            min = n
            mini = i
        end
    end
    return min,mini
end

function utils.anglesToTarget(current,target)
    local yaw = math.deg(math.atan2(current.z-target.z,current.x-target.x))
    local pitch = math.deg(math.atan2(current.y-(target.y),math.sqrt((current.z-target.z)^2+(current.x-target.x)^2)))
    return yaw,pitch
end

function utils.angleDiff(a,b)
    local d = {}
    d[1] = b-a
    d[2] = b-a+math.pi
    d[3] = b-a+2*math.pi
    d[4] = b-a-math.pi
    d[5] = b-a-2*math.pi
    return utils.amin(d)
end

function utils.round(x,n)
    return math.floor(x/n+0.499999)*n
end

local vec3 = {
    x=0,
    y=0,
    z=0,
    init=function(self,x,y,z)
        self.x=x
        self.y=y
        self.z=z
        return self
    end,
    copy=function(self)
        return utils.vec(self.x,self.y,self.z)
    end,
    map=function(self,fn)
        return utils.vec(
            fn(self.x),
            fn(self.y),
            fn(self.z)
        )
    end,
    mul=function(self,n)
        return self:map(function(x)
            return x*n
        end)
    end,
    add=function(self,v)
        local u = utils.vec(
            self.x+v.x,
            self.y+v.y,
            self.z+v.z
        )
        return u
    end,
    sub=function(self,v)
        return self:add(v:mul(-1))
    end,
    dot=function(self,v)
        return self.x*v.x+self.y*v.y+self.z*v.z
    end,
    cross=function(self,v)
        return utils.vec(
            self.y*v.z-self.z*v.y,
            self.z*v.x-self.x*v.z,
            self.x*v.y-self.y*v.x
        )
    end,
    len=function(self)
        return math.sqrt(self.x*self.x+self.y*self.y+self.z*self.z)
    end,
    round=function(self,n)
        local rtn = self
        rtn.x = utils.round(rtn.x,n)
        rtn.y = utils.round(rtn.y,n)
        rtn.z = utils.round(rtn.z,n)
        return rtn
    end,
    normalize=function(self)
        return self:copy():map(function(x)
            return x/self:len()
        end)
    end,
    rotate=function(self,pitch,yaw,roll)
        local mat={
            {math.cos(yaw)*math.cos(pitch),math.cos(yaw)*math.sin(pitch)*math.sin(roll)-math.sin(yaw)*math.cos(roll),math.cos(yaw)*math.sin(pitch)*math.cos(roll)+math.sin(yaw)*math.sin(roll)},
            {math.sin(yaw)*math.cos(pitch),math.sin(yaw)*math.sin(pitch)*math.sin(roll)+math.cos(yaw)*math.cos(roll),math.sin(yaw)*math.sin(pitch)*math.cos(roll)-math.cos(yaw)*math.sin(roll)},
            {-math.sin(pitch),math.cos(pitch)*math.sin(roll),math.cos(pitch)*math.cos(roll)}
        }
        return utils.vec(
            mat[1][1]*self.x+mat[1][2]*self.y+mat[1][3]*self.z,
            mat[2][1]*self.x+mat[2][2]*self.y+mat[2][3]*self.z,
            mat[3][1]*self.x+mat[3][2]*self.y+mat[3][3]*self.z
        )
    end,
    tostring=function(self)
        return "("..self.x..","..self.y..","..self.z..")"
    end,
    from=function(v)
        return utils.vec(v.x,v.y,v.z)
    end,
    muleach=function(self,v)
        return utils.vec(selc.x*v.x,self.y*v.y,self.z*v.z)
    end
}

utils.vec3 = utils.Class(vec3,"vec3")

utils.vec = function(x,y,z)
    return utils.vec3.new():init(x,y,z)
end

local PID = {
    params={
        kp=0,
        ki=0,
        kd=0,
        threshold=0
    },
    state = {
        lastError = nil,
        errorSum = 0,
        lastT = nil
    },
    get=function(self,n)end,
    set=function(self,n)end
}

--state:{kp:Num,ki:Num,kd:Num,threshold:Num},get:()=>Num,set(value:Num)
function PID:init(params,get,set)
    self.params = params
    self.get = get
    self.set = set
end

--target:Num
function PID:run(target)
    local state = self.state
    local p = self.params
    local t = os.clock()
    state.lastT = state.lastT or t
    local dt = t-state.lastT
    state.lastT = t
    local err = self:get(target)
    state.errorSum = math.abs(err)<self.params.threshold and state.errorSum+err or 0
    state.lastError = state.lastError or err
    local P = err*p.kp*dt
    local I = state.errorSum*p.ki*dt
    local D = (err-state.lastError)*p.kd*dt
    state.lastError = err
    self.state = state
    self:set(P+I+D)
    return self
end

utils.PID = utils.Class(PID,"PID")

local eventHandler = {
    ref = {},
    eventData = {}
}
function eventHandler:init(ref)
    self.ref = ref
end

function eventHandler:run()
    local fns = {
        function()
            self.eventData = {os.pullEvent()}
        end
    }
    for k,v in pairs(self.ref) do
        if not v.listener then
            fns[#fns+1] = function()
                while true do
                    v.fn()
                    sleep()
                end
            end
        else
            fns[#fns+1] = function()
                while true do
                    if self.eventData[1] == k then
                        v.fn(self.eventData)
                    end
                    sleep()
                end
            end
        end
    end
    while true do
        parallel.waitForAny(table.unpack(fns))
    end
end

utils.eventHandler = utils.Class(eventHandler,"eventHandler")

utils.trilaterate = function (r1,r2,r3,A, B, C)
    local a2b = B:sub(A)
    local a2c = C:sub(A)

    if math.abs(a2b:normalize():dot(a2c:normalize())) > 0.999 then
        return nil
    end

    local d = a2b:len()
    local ex = a2b:normalize( )
    local i = ex:dot(a2c)
    local ey = (a2c:sub(ex:mul(i))):normalize()
    local j = ey:dot(a2c)
    local ez = ex:cross(ey)

    local x = (r1 * r1 - r2 * r2 + d * d) / (2 * d)
    local y = (r1 * r1 - r3 * r3 - x * x + (x - i) * (x - i) + j * j) / (2 * j)

    local result = A:add(ex:mul(x)):add(ey:mul(y))

    local zSquared = r1 * r1 - x * x - y * y
    if zSquared > 0 then
        local z = math.sqrt(zSquared)
        local result1 = result:add(ez:mul(z))
        local result2 = result:sub(ez:mul(z))

        local rounded1, rounded2 = result1:round(0.01), result2:round(0.01)
        if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
            return rounded1, rounded2
        else
            return rounded1
        end
    end
    return result:round(0.01)
end

utils.narrow = function(p1, p2, fix, r)
    local dist1 = math.abs((p1:sub(fix)):len() - r)
    local dist2 = math.abs((p2:sub(fix)):len() - r)

    if math.abs(dist1 - dist2) < 0.01 then
        return p1, p2
    elseif dist1 < dist2 then
        return p1:round(0.01)
    else
        return p2:round(0.01)
    end
end

local constellation={
    modems={},
    modemPositions={},
    channel=314,
    init=function(self,modems,channel)
        self.modems = modems
        self.channel = channel or 314
        return self
    end,
    initstd=function(self,pos,channel)
        self.modems[1] = {p.wrap(p.wrap("left").getNamesRemote()[1]),utils.vec(pos.x-1,pos.y+1,pos.z)}
        self.modems[2] = {p.wrap(p.wrap("right").getNamesRemote()[1]),utils.vec(pos.x+1,pos.y+1,pos.z)}
        self.modems[3] = {p.wrap(p.wrap("back").getNamesRemote()[1]),utils.vec(pos.x,pos.y+1,pos.z-1)}
        self.modems[4] = {p.wrap(p.wrap("top").getNamesRemote()[1]),utils.vec(pos.x,pos.y+2,pos.z)}
        self.channel = channel or 314
        return self
    end,
    run=function(self)
        while true do
            for _,modem in pairs(self.modems) do
                modem[1].transmit(self.channel,self.channel,modem[2])
                sleep()
            end
            sleep()
        end
    end
}

local pointOfInterest={
    modem={},
    pos={},
    channel=314,
    init=function(self,modem,channel)
        self.debug = debug or false
        self.modem = modem
        self.channel = channel or 314
        return self
    end,
    getDistances = function(self)
        local i=0
        local r={}
        while i<4 do
            local _,modem,_,_,pos,d = os.pullEvent("modem_message")
            pos = utils.vec(pos.x,pos.y,pos.z)
            if d and modem == p.getName(self.modem) then
                self.pos[#self.pos+1] = pos
                r[#r+1] = d
                i=i+1
            end
        end
        return r
    end,
    locate=function(self)
        self.modem.open(self.channel)
        while true do
            local r = self:getDistances()
            local p1,p2 = utils.trilaterate(r[1],r[2],r[3],self.pos[1],self.pos[2],self.pos[3])
            if p1 and p2 then
                return utils.narrow(p1,p2,self.pos[4],r[4])
            elseif p1 then
                return p1
            end
        end
    end
}

utils.gps = {constellation=utils.Class(constellation,"constellation"),POI=utils.Class(pointOfInterest,"pointOfInterest")}

function utils.filter(t,filter)
    local rtn = {}
    for k,v in pairs(t) do
        if filter(k,v) then
            rtn[#rtn+1] = v
        end
    end
    return rtn
end

function utils.startsWith(s)
    return function (d)
        for i=1,s.len() do
            local c1 = string.sub(s,i,i)
            local c2 = string.sub(d,1,1)
            if c1 ~= c2 then
                return false
            end
        end
        return true
    end
end

function utils.find(type,modem)
    if not modem then
        return p.find(type)
    else
        local rtn = {}
        for _,per in pairs(modem.getNamesRemote()) do
            if p.hasType(per,type) then
                rtn[#rtn+1] = p.wrap(per)
            end
        end
        return rtn
    end
end

function utils.tabspace(n)
    local str = ""
    for i=1,n do
        str = str.."  "
    end
    return str
end

function utils.serialise(t,keys,tab)
    tab = tab or 0
    local str = tabspace(tab).."{\n"
    for k,v in pairs(t) do
        print(k)
        if keys then
            str = str..k..'\n'
        else
        if type(v) == "table" then
            str = str..k..'='..serialise(v,tab+1)
        else
            --print(v)
            str = str..k..'='..tabspace(tab+1)..v
        end
        str = str..',\n'
        end
        sleep()
    end
    str = str..tabspace(tab).."}"
    return str
end
function utils.hexToDec(hex)
    local lookup = {
        ["0"]=0,
        ["1"]=1,
        ["2"]=2,
        ["3"]=3,
        ["4"]=4,
        ["5"]=5,
        ["6"]=6,
        ["7"]=7,
        ["8"]=8,
        ["9"]=9,
        ["a"]=10,
        ["b"]=11,
        ["c"]=12,
        ["d"]=13,
        ["e"]=14,
        ["f"]=15,
    }
    local n = 0
    for i=1,#hex do
        n = n + lookup[hex:sub(i,i)]*16^(#hex-i)
    end
    return n
end

return utils