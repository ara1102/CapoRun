import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // Nodes
    private var player: SKSpriteNode!
    private var scoreLabel: SKLabelNode!
    
    // State
    private var currentLane: Int = 0
    private var isSliding: Bool = false
    private var score: Int = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    private var isWaitingForCorrectAnswer = false
    private var stuckRowNode: SKNode? = nil
    private var safeLaneForStuckRow: Int? = nil
    
    private let numLanes = 4
    
    // 3D Perspective Math
    private var horizonY: CGFloat { size.height * 0.65 }
    private var playerY: CGFloat { size.height * 0.15 }
    private let cameraHeight: CGFloat = 10.0
    private let startZ: CGFloat = 100.0
    private let endZ: CGFloat = -15.0
    private let obstacleDuration: TimeInterval = 3.0
    
    private var baseLaneWidth: CGFloat {
        (size.width * 0.8) / CGFloat(numLanes)
    }
    
    private func logicalX(for lane: Int) -> CGFloat {
        return (CGFloat(lane) - 1.5) * baseLaneWidth
    }
    
    private func perspectiveScale(z: CGFloat) -> CGFloat {
        return cameraHeight / (cameraHeight + z)
    }
    
    private func screenY(scale: CGFloat) -> CGFloat {
        return horizonY - (horizonY - playerY) * scale
    }
    
    // Constants
    private let obstacleSpawnRate: TimeInterval = 1.5
    
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
        startSpawningObstacles()
    }
    
    private func setupLanes() {
        let centerX = size.width / 2
        
        // Synthwave Sun
        let sun = SKShapeNode(circleOfRadius: size.width * 0.25)
        sun.fillColor = UIColor(red: 1.0, green: 0.2, blue: 0.5, alpha: 1.0)
        sun.strokeColor = .clear
        sun.position = CGPoint(x: centerX, y: horizonY)
        sun.zPosition = -5
        
        // Sun glow
        let glow = SKEffectNode()
        glow.shouldEnableEffects = true
        let filter = CIFilter(name: "CIGaussianBlur")!
        filter.setValue(30.0, forKey: "inputRadius")
        glow.filter = filter
        let sunCopy = sun.copy() as! SKShapeNode
        glow.addChild(sunCopy)
        glow.zPosition = -6
        addChild(glow)
        addChild(sun)
        
        // Horizon line glow
        let horizonLine = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: 4))
        horizonLine.fillColor = UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1.0)
        horizonLine.strokeColor = .clear
        horizonLine.position = CGPoint(x: centerX, y: horizonY)
        horizonLine.zPosition = -4
        
        let horizonGlow = SKEffectNode()
        horizonGlow.shouldEnableEffects = true
        horizonGlow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 10.0])
        horizonGlow.addChild(horizonLine.copy() as! SKShapeNode)
        horizonGlow.zPosition = -5
        addChild(horizonGlow)
        addChild(horizonLine)
        
        // Ground Grid Lines
        let groundScale = horizonY / (horizonY - playerY)
        
        for i in 0...numLanes {
            let logicX = (CGFloat(i) - 2.0) * baseLaneWidth
            let bottomX = centerX + logicX * groundScale
            
            let path = CGMutablePath()
            path.move(to: CGPoint(x: centerX, y: horizonY))
            path.addLine(to: CGPoint(x: bottomX, y: 0))
            
            let line = SKShapeNode(path: path)
            line.strokeColor = UIColor(red: 0.8, green: 0.0, blue: 0.8, alpha: 0.6)
            line.lineWidth = 3.0
            line.zPosition = -3
            addChild(line)
        }
    }
    
    private func setupPlayer() {
        let playerSize = CGSize(width: baseLaneWidth * 0.6, height: baseLaneWidth * 0.6)
        player = SKSpriteNode(color: UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 0.9), size: playerSize)
        
        let borderPath = CGPath(rect: CGRect(x: -playerSize.width/2, y: -playerSize.height/2, width: playerSize.width, height: playerSize.height), transform: nil)
        let border = SKShapeNode(path: borderPath)
        border.strokeColor = .white
        border.lineWidth = 3.0
        player.addChild(border)
        
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
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 28
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 60)
        scoreLabel.text = "Score: 0"
        scoreLabel.zPosition = 1000
        addChild(scoreLabel)
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
        rowNode.setScale(initialScale)
        
        for i in 0..<numLanes {
            let blockX = logicalX(for: i)
            
            if i == safeLane {
                let scoreNode = SKSpriteNode(color: .clear, size: CGSize(width: baseLaneWidth * 0.9, height: obstacleLogicalHeight))
                scoreNode.position = CGPoint(x: blockX, y: 0)
                
                let safePath = CGPath(rect: CGRect(x: -baseLaneWidth*0.45, y: -obstacleLogicalHeight/2, width: baseLaneWidth*0.9, height: obstacleLogicalHeight), transform: nil)
                let safeOutline = SKShapeNode(path: safePath)
                safeOutline.strokeColor = UIColor(red: 0.0, green: 1.0, blue: 0.5, alpha: 0.6)
                safeOutline.lineWidth = 5.0
                scoreNode.addChild(safeOutline)
                
                scoreNode.physicsBody = SKPhysicsBody(rectangleOf: scoreNode.size)
                scoreNode.physicsBody?.isDynamic = false
                scoreNode.physicsBody?.categoryBitMask = scoreCategory
                scoreNode.physicsBody?.contactTestBitMask = playerCategory
                scoreNode.physicsBody?.collisionBitMask = 0
                
                rowNode.addChild(scoreNode)
            } else {
                let blockNode = SKSpriteNode(color: UIColor(red: 1.0, green: 0.0, blue: 0.8, alpha: 0.8), size: CGSize(width: baseLaneWidth * 0.95, height: obstacleLogicalHeight))
                blockNode.position = CGPoint(x: blockX, y: 0)
                
                let borderPath = CGPath(rect: CGRect(x: -baseLaneWidth*0.475, y: -obstacleLogicalHeight/2, width: baseLaneWidth*0.95, height: obstacleLogicalHeight), transform: nil)
                let border = SKShapeNode(path: borderPath)
                border.strokeColor = UIColor(red: 1.0, green: 0.5, blue: 1.0, alpha: 1.0)
                border.lineWidth = 3.0
                blockNode.addChild(border)
                
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
            node.setScale(scale)
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
    }
    
    // MARK: - Collision Handling
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == (playerCategory | obstacleCategory) {
            if !isWaitingForCorrectAnswer && !isSliding {
                let obstacleNode = contact.bodyA.categoryBitMask == obstacleCategory ? contact.bodyA.node : contact.bodyB.node
                if let rowNode = obstacleNode?.parent {
                    handleCollision(with: rowNode)
                }
            }
        } else if collision == (playerCategory | scoreCategory) {
            if let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node {
                let scoreNode = contact.bodyA.categoryBitMask == scoreCategory ? nodeA : nodeB
                scoreNode.removeFromParent()
                score += 1
            }
        }
    }
    
    private func handleCollision(with rowNode: SKNode) {
        isWaitingForCorrectAnswer = true
        stuckRowNode = rowNode
        safeLaneForStuckRow = rowNode.userData?["safeLane"] as? Int
        
        enumerateChildNodes(withName: "obstacleRow") { node, _ in
            node.isPaused = true
        }
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
    }
}
