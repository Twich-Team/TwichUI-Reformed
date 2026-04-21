--- Performance helpers for memory profiling, rendering optimization, object pooling, and render batching for Midnight 12.0

local Performance = {}

-- Object pool for textures
Performance.texturePool = setmetatable({}, { __mode = "k" })

function Performance:GetPooledTexture()
    local tex = table.remove(self.texturePool)
    if tex then return tex end
    tex = CreateTexture(nil, "ARTWORK")
    return tex
end

function Performance:ReleaseTexture(tex)
    if tex then
        tex:SetTexture(nil)
        table.insert(self.texturePool, tex)
    end
end

-- Simple render batcher using C_Timer.After
Performance.batchQueue = {}
Performance.isBatchRunning = false

function Performance:QueueRender(callback)
    table.insert(self.batchQueue, callback)
    if not self.isBatchRunning then
        self.isBatchRunning = true
        C_Timer.After(0.01, function() self:RunBatch() end)
    end
end

function Performance:RunBatch()
    local q = self.batchQueue
    self.batchQueue = {}
    for _,cb in ipairs(q) do
        pcall(cb)
    end
    self.isBatchRunning = false
end

-- Simple GC profiling
Performance.lastGC = 0
function Performance:Start()
    self.lastGC = collectgarbage("count")
end
function Performance:Report()
    local cur = collectgarbage("count")
    local diff = cur - (self.lastGC or cur)
    print(string.format("[Performance] Memory usage change: %.2f KB", diff))
    self.lastGC = cur
end

return Performance
