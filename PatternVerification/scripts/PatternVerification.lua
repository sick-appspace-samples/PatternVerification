
--Start of Global Scope---------------------------------------------------------

print('AppEngine Version: ' .. Engine.getVersion())

local DELAY = 1000 -- ms between visualization steps for demonstration purpose

-- Variable for holding table of verifiers
local verifiers = {}

-- Creating viewer
local viewer = View.create()

-- Setting up graphical overlay attributes
local teachDecoration = View.ShapeDecoration.create()
teachDecoration:setLineWidth(4):setLineColor(0, 0, 230) -- Blue for "teach"

local failDecoration = View.ShapeDecoration.create()
failDecoration:setLineWidth(4):setLineColor(230, 0, 0) -- Red for "fail"

local passDecoration = View.ShapeDecoration.create()
passDecoration:setLineWidth(4):setLineColor(0, 230, 0) -- Green for "pass"

local textDecoration = View.TextDecoration.create():setPosition(25, 45)
textDecoration:setSize(35):setColor(255, 255, 0)

-- Create a PatternMatcher instance and set parameters
-- Note that a PointMatcher possibly can be used as well here
local matcher = Image.Matching.PatternMatcher.create()
matcher:setRotationRange(3.1415 / 4)
matcher:setMaxMatches(5)
matcher:setDownsampleFactor(10)
matcher:setTimeout(60)

-- Creating fixture
local fixture = Image.Fixture.create()

-- Defining threshold for pass
local errorScoreThreshold = 0.85

--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

---@param img Image
---@return Transform
local function teachShape(img)
  -- Defining object teach region
  local center = Point.create(280, 180)
  local teachRectangle = Shape.createRectangle(center, 170, 200)
  local teachRegion = teachRectangle:toPixelRegion(img)
  viewer:addShape(teachRectangle, teachDecoration)

  -- Teaching
  local matcherTeachPose = matcher:teach(img, teachRegion)
  fixture:setReferencePose(matcherTeachPose)
  fixture:appendShape('objectBox', teachRectangle)
  return matcherTeachPose
end

---Routine for adding and teaching one verifier
---@param teachImage Image
---@param keyName string
---@param keyRegion Image.PixelRegion
local function addVerifier(teachImage, keyName, keyRegion)
  verifiers[keyName] = Image.Matching.PatternVerifier.create()
  verifiers[keyName]:setPositionTolerance(3)
  verifiers[keyName]:setRotationTolerance(math.rad(1))
  local keyPose = verifiers[keyName]:teach(teachImage, keyRegion)
  fixture:appendPose(keyName, keyPose)
  fixture:appendShape(keyName, keyRegion:getBoundingBoxOriented(teachImage))
end

---@param teachPose Transform
---@param img Image
local function teachPatterns(teachPose, img)
  -- Key regions
  local printScreen = Image.PixelRegion.createRectangle(220, 103, 249, 137)
  local scrollLock = Image.PixelRegion.createRectangle(265, 103, 294, 139)
  local pause = Image.PixelRegion.createRectangle(309, 103, 338, 140)
  local insert = Image.PixelRegion.createRectangle(218, 166, 249, 201)
  local home = Image.PixelRegion.createRectangle(263, 166, 294, 201)
  local pageUp = Image.PixelRegion.createRectangle(308, 166, 337, 202)
  local delete = Image.PixelRegion.createRectangle(219, 212, 249, 246)
  local endButton = Image.PixelRegion.createRectangle(264, 213, 293, 248)
  local pageDown = Image.PixelRegion.createRectangle(308, 212, 336, 246)

  -- Teaching verifiers for keys
  addVerifier(img, 'PrintScreen', printScreen)
  addVerifier(img, 'ScrollLock', scrollLock)
  addVerifier(img, 'Pause', pause)
  addVerifier(img, 'Insert', insert)
  addVerifier(img, 'Home', home)
  addVerifier(img, 'PageUp', pageUp)
  addVerifier(img, 'Delete', delete)
  addVerifier(img, 'End', endButton)
  addVerifier(img, 'PageDown', pageDown)
  -- Draw teach regions
  fixture:transform(teachPose)
  for keyName, _ in pairs(verifiers) do
    local bbox = fixture:getShape(keyName)
    viewer:addShape(bbox, teachDecoration)
  end

  viewer:addText('Teach', textDecoration)

  viewer:present()
end

---@param img Image
local function match(img)
  viewer:clear()
  viewer:addImage(img)
  -- Finding object
  local poses,
    scores = matcher:match(img)
  local livePose = poses[1]
  local liveScore = scores[1]
  print('Object score: ' .. math.floor(liveScore * 100) / 100)

  -- Drawing object rectangle
  fixture:transform(livePose)
  local objectRectangle = fixture:getShape('objectBox')
  viewer:addShape(objectRectangle, passDecoration)

  -- Verifying each key, draw box with color depending on verifier score
  local textContent = 'Pass'
  for keyName, verifier in pairs(verifiers) do
    local score, _, _ = verifier:verify(img, fixture:getPose(keyName))
    local bbox = fixture:getShape(keyName)
    if (score > errorScoreThreshold) then
      viewer:addShape(bbox, passDecoration)
    else
      viewer:addShape(bbox, failDecoration)
      textContent = 'Fail'
    end
    print(keyName .. ' score: ' .. tostring(math.floor(score * 100) / 100))
  end

  viewer:addText(textContent, textDecoration)
  viewer:present()
end

local function main()
  -- Loading Teach image from resources and teaching
  local teachImage = Image.load('resources/Teach.bmp')
  viewer:clear()
  viewer:addImage(teachImage)
  local matcherTeachPose = teachShape(teachImage)
  -- Teaching patterns to verify
  teachPatterns(matcherTeachPose, teachImage)
  Script.sleep(DELAY * 1.5)

  -- Loading images from resource folder and calling function for verification
  for i = 1, 3 do
    local liveImage = Image.load('resources/' .. i .. '.bmp')
    print('-------------------------')
    print('OBJECT ' .. i)
    match(liveImage)
    Script.sleep(DELAY)
  end

  print('App finished.')
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register('Engine.OnStarted', main)

--End of Function and Event Scope--------------------------------------------------
