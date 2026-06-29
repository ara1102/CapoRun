import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // Nodes
    private var player: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    var onGameEnd: (() -> Void)?
    
    // State
    private var currentLane: Int = 0
    private var isSliding: Bool = false
    private let scoreGoal: Int = 100
    private var score: Int = 0 {
        didSet {
            updateScoreLabel()
            if score >= scoreGoal {
                winGame()
            }
        }
    }
    
    private var scoreBackground: SKShapeNode!
    private var healthBarBackground: SKShapeNode!
    private var healthBarFill: SKShapeNode!
    
    private func updateScoreLabel() {
        scoreLabel.text = "Score: \(score)/\(scoreGoal)"
    }
    
    private var isWaitingForCorrectAnswer = false
    private var stuckRowNode: SKNode? = nil
    private var safeLaneForStuckRow: Int? = nil
    
    private let numLanes = 4
    
    // 3D Perspective Math & Calibration
    // Adjust roadWidthScale to make the lanes wider (e.g. 0.9) or narrower (e.g. 0.7)
    private let roadWidthScale: CGFloat = 1
    // Adjust vanishingYOffset to change where the lanes converge vertically in the image
    private let vanishingYOffset: CGFloat = 42.0
    // Adjust horizonWidthFraction to widen the lanes at the horizon (0.0 = point convergence, 0.2 = 20% of width)
    private let horizonWidthFraction: CGFloat = 0.17
    
    private var horizonY: CGFloat { size.height * 0.65 }
    private var playerY: CGFloat { size.height * 0.15 }
    private let cameraHeight: CGFloat = 10.0
    private let startZ: CGFloat = 100.0
    private let endZ: CGFloat = -15.0
    private let obstacleDuration: TimeInterval = 3.0
    
    private var baseLaneWidth: CGFloat {
        (size.width * roadWidthScale) / CGFloat(numLanes)
    }
    
    private func logicalX(for lane: Int) -> CGFloat {
        return (CGFloat(lane) - 1.5) * baseLaneWidth
    }
    
    private func perspectiveScale(z: CGFloat) -> CGFloat {
        return cameraHeight / (cameraHeight + z)
    }
    
    private func screenY(scale: CGFloat) -> CGFloat {
        let vanishingY = horizonY + vanishingYOffset
        return vanishingY - (vanishingY - playerY) * scale
    }
    
    private let barrierNames = ["BarrierRed", "BarrierYellow", "BarrierPurple", "BarrierCyan"]
    
    // Constants
    private let obstacleSpawnRate: TimeInterval = 2.0
    
    // Physics Categories
    private let playerCategory: UInt32 = 0x1 << 0
    private let obstacleCategory: UInt32 = 0x1 << 1
    private let scoreCategory: UInt32 = 0x1 << 2
    
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.04, green: 0.02, blue: 0.1, alpha: 1.0)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        setupLanes()
        setupPlayer()
        setupHUD()
    }
    
    func startGame() {
        startCountdown()
    }
    
    private func setupLanes() {
        let centerX = size.width / 2
        
        // 1. Game Background
        let background = SKSpriteNode(imageNamed: "GameBackground")
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        // Scale up size by 1.1x to prevent showing black corners when rotated
        background.size = CGSize(width: size.width * 1.1, height: size.height * 1.1)
        background.zPosition = -10
        background.zRotation = 0.0 // Tilts background slightly (counter-clockwise)
        addChild(background)
        
        // 2. 4-Lane Road Sprite
        let road = SKSpriteNode(imageNamed: "Road4Lanes")
        road.anchorPoint = CGPoint(x: 0.5, y: 0) // Anchor at bottom-center
        road.position = CGPoint(x: centerX, y: 0)
        road.size = CGSize(width: size.width, height: horizonY)
        road.zPosition = -3
        addChild(road)
        
        // Synthwave Sun (placed on top of background but behind road)
        let sun = SKShapeNode(circleOfRadius: size.width * 0.25)
        sun.fillColor = UIColor(red: 1.0, green: 0.2, blue: 0.5, alpha: 1.0)
        sun.strokeColor = .clear
        sun.position = CGPoint(x: centerX, y: horizonY)
        sun.zPosition = -5
        
        // // Sun glow
        // let glow = SKEffectNode()
        // glow.shouldEnableEffects = true
        // let filter = CIFilter(name: "CIGaussianBlur")!
        // filter.setValue(30.0, forKey: "inputRadius")
        // glow.filter = filter
        // let sunCopy = sun.copy() as! SKShapeNode
        // glow.addChild(sunCopy)
        // glow.zPosition = -6
        // addChild(glow)
        // addChild(sun)
        
         // Horizon line glow
        //  let horizonLine = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: 4))
        //  horizonLine.fillColor = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
        //  horizonLine.strokeColor = .clear
        //  horizonLine.position = CGPoint(x: centerX, y: horizonY)
        //  horizonLine.zPosition = -4
        
        //  let horizonGlow = SKEffectNode()
        //  horizonGlow.shouldEnableEffects = true
        //  horizonGlow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 10.0])
        //  horizonGlow.addChild(horizonLine.copy() as! SKShapeNode)
        //  horizonGlow.zPosition = -5
        //  addChild(horizonGlow)
        //  addChild(horizonLine)
    }
    
    private func setupPlayer() {
        let playerSize = CGSize(width: baseLaneWidth * 0.6, height: baseLaneWidth * 0.6)
        let initialTextureName = (currentLane == 0 || currentLane == 1) ? "CharacterRunningLeft" : "CharacterRunningRight"
        let defaultTexture = SKTexture(imageNamed: initialTextureName)
        player = SKSpriteNode(texture: defaultTexture, size: playerSize)
        
        player.position = CGPoint(x: size.width / 2 + logicalX(for: currentLane), y: playerY)
        player.zPosition = 110
        
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.categoryBitMask = playerCategory
        player.physicsBody?.contactTestBitMask = obstacleCategory | scoreCategory
        player.physicsBody?.collisionBitMask = 0
        
        addChild(player)
    }
    
    private func setupHUD() {
        let bgWidth: CGFloat = 200
        let bgHeight: CGFloat = 44
        let bgRect = CGRect(x: -bgWidth/2, y: -12, width: bgWidth, height: bgHeight)
        
        scoreBackground = SKShapeNode(rect: bgRect, cornerRadius: 15)
        scoreBackground.fillColor = UIColor.black.withAlphaComponent(0.8)
        scoreBackground.strokeColor = .clear
        scoreBackground.position = CGPoint(x: size.width / 2, y: size.height - 240)
        scoreBackground.zPosition = 999
        addChild(scoreBackground)
        
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 240)
        scoreLabel.zPosition = 1000
        addChild(scoreLabel)
        
        updateScoreLabel()
    }
    
    private func startCountdown() {
        let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        countdownLabel.fontSize = 50
        countdownLabel.fontColor = .white
        countdownLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        countdownLabel.zPosition = 2000
        addChild(countdownLabel)
        
        let prepText = SKAction.run { countdownLabel.text = "Get Ready!" }
        let text3 = SKAction.run { countdownLabel.text = "3" }
        let text2 = SKAction.run { countdownLabel.text = "2" }
        let text1 = SKAction.run { countdownLabel.text = "1" }
        let goText = SKAction.run { 
            countdownLabel.text = "STRUM!" 
            countdownLabel.fontColor = .systemGreen
            countdownLabel.fontSize = 60
        }
        
        let waitShort = SKAction.wait(forDuration: 1.0)
        let waitLong = SKAction.wait(forDuration: 1.5)
        
        // Add a little pop animation for the countdown numbers
        let scaleUp = SKAction.scale(to: 1.2, duration: 0.1)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        let pop = SKAction.sequence([scaleUp, scaleDown])
        
        let text3Pop = SKAction.group([text3, pop])
        let text2Pop = SKAction.group([text2, pop])
        let text1Pop = SKAction.group([text1, pop])
        let goPop = SKAction.group([goText, scaleUp])
        
        let remove = SKAction.removeFromParent()
        let startSpawning = SKAction.run { [weak self] in
            self?.startSpawningObstacles()
        }
        
        let sequence = SKAction.sequence([
            prepText, waitLong,
            text3Pop, waitShort,
            text2Pop, waitShort,
            text1Pop, waitShort,
            goPop, waitShort,
            remove, startSpawning
        ])
        
        countdownLabel.run(sequence)
    }
    
    private func startSpawningObstacles() {
        let spawnAction = SKAction.run { [weak self] in
            guard let self = self, !self.isWaitingForCorrectAnswer else { return }
            self.spawnObstacle()
        }
        let waitAction = SKAction.wait(forDuration: obstacleSpawnRate)
        let sequence = SKAction.sequence([spawnAction, waitAction])
        run(SKAction.repeatForever(sequence), withKey: "spawnLoop")
    }
    
    private func spawnObstacle() {
        let safeLane = Int.random(in: 0..<numLanes)
        let obstacleLogicalHeight: CGFloat = baseLaneWidth * 0.5
        
        let rowNode = SKNode()
        rowNode.name = "obstacleRow"
        rowNode.userData = ["safeLane": safeLane]
        
        let initialScale = perspectiveScale(z: startZ)
        rowNode.position = CGPoint(x: size.width / 2, y: screenY(scale: initialScale))
        let initialLaneScale = initialScale + (1.0 - initialScale) * horizonWidthFraction
        rowNode.xScale = initialLaneScale
        rowNode.yScale = initialScale
        
        for i in 0..<numLanes {
            let blockX = logicalX(for: i)
            
            if i == safeLane {
                let scoreNode = SKSpriteNode(color: .clear, size: CGSize(width: baseLaneWidth * 0.9, height: obstacleLogicalHeight))
                scoreNode.position = CGPoint(x: blockX, y: 0)
                
                // let safePath = CGPath(rect: CGRect(x: -baseLaneWidth*0.45, y: -obstacleLogicalHeight/2, width: baseLaneWidth*0.9, height: obstacleLogicalHeight), transform: nil)
                // let safeOutline = SKShapeNode(path: safePath)
                // safeOutline.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.6)
                // safeOutline.lineWidth = 5.0
                // scoreNode.addChild(safeOutline)
                
                scoreNode.physicsBody = SKPhysicsBody(rectangleOf: scoreNode.size)
                scoreNode.physicsBody?.isDynamic = false
                scoreNode.physicsBody?.categoryBitMask = scoreCategory
                scoreNode.physicsBody?.contactTestBitMask = playerCategory
                scoreNode.physicsBody?.collisionBitMask = 0
                
                rowNode.addChild(scoreNode)
            } else {
                let barrierName = self.barrierNames[i % self.barrierNames.count]
                let blockNode = SKSpriteNode(imageNamed: barrierName)
                blockNode.size = CGSize(width: baseLaneWidth * 0.95, height: obstacleLogicalHeight)
                blockNode.position = CGPoint(x: blockX, y: 0)
                
                blockNode.physicsBody = SKPhysicsBody(rectangleOf: blockNode.size)
                blockNode.physicsBody?.isDynamic = false
                blockNode.physicsBody?.categoryBitMask = obstacleCategory
                blockNode.physicsBody?.contactTestBitMask = playerCategory
                blockNode.physicsBody?.collisionBitMask = 0
                
                rowNode.addChild(blockNode)
            }
        }
        
        addChild(rowNode)
        
        // 3D Perspective Animation
        let move3D = SKAction.customAction(withDuration: obstacleDuration) { [weak self] node, elapsedTime in
            guard let self = self else { return }
            let fraction = elapsedTime / CGFloat(self.obstacleDuration)
            let currentZ = self.startZ + (self.endZ - self.startZ) * fraction
            
            let scale = self.perspectiveScale(z: currentZ)
            let laneScale = scale + (1.0 - scale) * self.horizonWidthFraction
            node.xScale = laneScale
            node.yScale = scale
            node.position.y = self.screenY(scale: scale)
            node.zPosition = 100 - currentZ
        }
        
        let remove = SKAction.removeFromParent()
        rowNode.run(SKAction.sequence([move3D, remove]))
    }
    
    // MARK: - Input Handling
    
    private var activeSafeLane: Int? {
        if isWaitingForCorrectAnswer {
            return safeLaneForStuckRow
        }
        
        var nearestRow: SKNode? = nil
        var minDistance: CGFloat = .greatestFiniteMagnitude
        
        enumerateChildNodes(withName: "obstacleRow") { node, _ in
            let distance = node.position.y - self.playerY
            // Consider obstacles within a reasonable range (allows them to slightly pass the player)
            if distance > -50 && distance < minDistance {
                minDistance = distance
                nearestRow = node
            }
        }
        
        return nearestRow?.userData?["safeLane"] as? Int
    }
    
    func changeLane(to chord: String) {
        /*
        guard let safeLane = activeSafeLane else { return }
        
        var correctChords: [String] = []
        switch safeLane {
        case 0: correctChords = ["C"]
        case 1: correctChords = ["D"]
        case 2: correctChords = ["Am"]
        case 3: correctChords = ["G"]
        default: return
        }
        
        if correctChords.contains(chord) {
            if currentLane != safeLane {
                currentLane = safeLane
                let targetX = size.width / 2 + logicalX(for: safeLane)
                
                isSliding = true
                let moveAction = SKAction.moveTo(x: targetX, duration: 0.15)
                let finishSliding = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.isSliding = false
                    
                    if self.isWaitingForCorrectAnswer {
                        self.resumeFromCollision()
                    }
                }
                player.run(SKAction.sequence([moveAction, finishSliding]))
            }
        }
        */
        
        // Map chords directly to their corresponding lanes
        let targetLane: Int?
        switch chord {
        case "C": targetLane = 0
        case "D": targetLane = 1
        case "Am": targetLane = 2
        case "G": targetLane = 3
        default: targetLane = nil
        }
        
        guard let lane = targetLane else { return }
        
        if currentLane != lane {
            currentLane = lane
            let targetX = size.width / 2 + logicalX(for: lane)
            
            // 12 (0 and 1) use assets running left, 34 (2 and 3) use assets running right
            let textureName = (lane == 0 || lane == 1) ? "CharacterRunningLeft" : "CharacterRunningRight"
            player.texture = SKTexture(imageNamed: textureName)
            
            isSliding = true
            let moveAction = SKAction.moveTo(x: targetX, duration: 0.15)
            let finishSliding = SKAction.run { [weak self] in
                guard let self = self else { return }
                self.isSliding = false
                
                // If stuck due to a collision, resume only if we moved to the safe lane
                if self.isWaitingForCorrectAnswer {
                    if let safeLane = self.safeLaneForStuckRow, lane == safeLane {
                        self.resumeFromCollision()
                    }
                }
            }
            player.run(SKAction.sequence([moveAction, finishSliding]))
        }
    }
    
    func playChordSound(chord: String) {
        let soundName = "\(chord).wav"
        
        if Bundle.main.path(forResource: chord, ofType: "wav", inDirectory: "AudioAsset") != nil {
            run(SKAction.playSoundFileNamed("AudioAsset/\(soundName)", waitForCompletion: false))
        } else if Bundle.main.path(forResource: chord, ofType: "wav") != nil {
            run(SKAction.playSoundFileNamed(soundName, waitForCompletion: false))
        }
    }
    
    // MARK: - Collision Handling
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == (playerCategory | obstacleCategory) {
            if !isWaitingForCorrectAnswer && !isSliding {
                let obstacleNode = contact.bodyA.categoryBitMask == obstacleCategory ? contact.bodyA.node : contact.bodyB.node
                if let rowNode = obstacleNode?.parent {
                    handleCollision(with: rowNode, obstacleNode: obstacleNode!)
                }
            }
        } else if collision == (playerCategory | scoreCategory) {
            if let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node {
                let scoreNode = contact.bodyA.categoryBitMask == scoreCategory ? nodeA : nodeB
                scoreNode.removeFromParent()
                score += 5
                showFloatingScore()
            }
        }
    }
    
    private func showFloatingScore() {
        let floatingLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        floatingLabel.text = "+5"
        floatingLabel.fontSize = 32
        floatingLabel.fontColor = .systemGreen
        floatingLabel.position = CGPoint(x: player.position.x, y: player.position.y + 40)
        floatingLabel.zPosition = 1000
        addChild(floatingLabel)
        
        let moveUp = SKAction.moveBy(x: 0, y: 50, duration: 1.0)
        let fadeOut = SKAction.fadeOut(withDuration: 1.0)
        let group = SKAction.group([moveUp, fadeOut])
        let remove = SKAction.removeFromParent()
        
        floatingLabel.run(SKAction.sequence([group, remove]))
    }
    
    private func handleCollision(with rowNode: SKNode, obstacleNode: SKNode) {
        // Stop the scene elements and wait for correct answer
        isWaitingForCorrectAnswer = true
        stuckRowNode = rowNode
        safeLaneForStuckRow = rowNode.userData?["safeLane"] as? Int
        
        // Pause all obstacle rows
        enumerateChildNodes(withName: "obstacleRow") { node, _ in
            node.isPaused = true
        }
        
        // Blink player to indicate hit
        let colorize = SKAction.colorize(with: .red, colorBlendFactor: 0.8, duration: 0.1)
        let uncolorize = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        let blink = SKAction.sequence([colorize, uncolorize, colorize, uncolorize])
        player.run(blink)
    }
    
    private func resumeFromCollision() {
        isWaitingForCorrectAnswer = false
        stuckRowNode = nil
        safeLaneForStuckRow = nil
        
        enumerateChildNodes(withName: "obstacleRow") { node, _ in
            node.isPaused = false
        }
    }
    
    func resetGame() {
        score = 0
        currentLane = 0
        isWaitingForCorrectAnswer = false
        stuckRowNode = nil
        safeLaneForStuckRow = nil
        
        enumerateChildNodes(withName: "obstacleRow") { node, _ in
            node.removeFromParent()
        }
        
        player.removeAllActions()
        player.position = CGPoint(x: size.width / 2 + logicalX(for: currentLane), y: playerY)
        let resetTextureName = (currentLane == 0 || currentLane == 1) ? "CharacterRunningLeft" : "CharacterRunningRight"
        player.texture = SKTexture(imageNamed: resetTextureName)
        
        isPaused = false
        if let gameOverLabel = childNode(withName: "gameOverLabel") {
            gameOverLabel.removeFromParent()
        }
    }
    
    private func gameOver() {
        isPaused = true
        
        let gameOverLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gameOverLabel.name = "gameOverLabel"
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = .systemRed
        gameOverLabel.text = "Game Over!"
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gameOverLabel.zPosition = 1000
        addChild(gameOverLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.onGameEnd?()
        }
    }
    
    private func winGame() {
        isPaused = true
        
        let winLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        winLabel.name = "gameOverLabel" // cleared on reset
        winLabel.fontSize = 40
        winLabel.fontColor = .systemGreen
        winLabel.text = "You Win!"
        winLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        winLabel.zPosition = 1000
        addChild(winLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.onGameEnd?()
        }
    }
}
