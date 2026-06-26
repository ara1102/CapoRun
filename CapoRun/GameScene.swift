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
    private var laneWidth: CGFloat {
        return size.width / CGFloat(numLanes)
    }
    
    // Constants
    private let playerYPositionMultiplier: CGFloat = 0.15
    private let obstacleSpawnRate: TimeInterval = 2.0
    private let obstacleDuration: TimeInterval = 3.0
    
    // Physics Categories
    private let playerCategory: UInt32 = 0x1 << 0
    private let obstacleCategory: UInt32 = 0x1 << 1
    private let scoreCategory: UInt32 = 0x1 << 2
    
    override func didMove(to view: SKView) {
        backgroundColor = .darkGray
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        setupLanes()
        setupPlayer()
        setupHUD()
        startSpawningObstacles()
    }
    
    private func setupLanes() {
        // Draw lane dividers for visual aid
        for i in 1..<numLanes {
            let x = CGFloat(i) * laneWidth
            let divider = SKSpriteNode(color: .lightGray, size: CGSize(width: 2, height: size.height))
            divider.position = CGPoint(x: x, y: size.height / 2)
            divider.zPosition = -1
            divider.alpha = 0.5
            addChild(divider)
        }
    }
    
    private func setupPlayer() {
        // Dummy player is a blue square
        player = SKSpriteNode(color: .systemBlue, size: CGSize(width: laneWidth * 0.6, height: laneWidth * 0.6))
        player.position = positionFor(lane: currentLane, y: size.height * playerYPositionMultiplier)
        player.zPosition = 10
        
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.categoryBitMask = playerCategory
        player.physicsBody?.contactTestBitMask = obstacleCategory | scoreCategory
        player.physicsBody?.collisionBitMask = 0
        
        addChild(player)
    }
    
    private func setupHUD() {
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: size.width / 2, y: size.height - 50)
        scoreLabel.text = "Score: 0"
        scoreLabel.zPosition = 100
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
        let obstacleHeight: CGFloat = 40.0
        
        let rowNode = SKNode()
        rowNode.name = "obstacleRow"
        rowNode.userData = ["safeLane": safeLane]
        rowNode.position = CGPoint(x: 0, y: size.height + obstacleHeight)
        
        for i in 0..<numLanes {
            if i == safeLane {
                // Score trigger node in the safe lane
                let scoreNode = SKSpriteNode(color: .clear, size: CGSize(width: laneWidth, height: obstacleHeight))
                scoreNode.position = CGPoint(x: (CGFloat(i) + 0.5) * laneWidth, y: 0)
                
                scoreNode.physicsBody = SKPhysicsBody(rectangleOf: scoreNode.size)
                scoreNode.physicsBody?.isDynamic = false
                scoreNode.physicsBody?.categoryBitMask = scoreCategory
                scoreNode.physicsBody?.contactTestBitMask = playerCategory
                scoreNode.physicsBody?.collisionBitMask = 0
                
                rowNode.addChild(scoreNode)
            } else {
                // Block node
                let blockNode = SKSpriteNode(color: .systemYellow, size: CGSize(width: laneWidth, height: obstacleHeight))
                blockNode.position = CGPoint(x: (CGFloat(i) + 0.5) * laneWidth, y: 0)
                
                blockNode.physicsBody = SKPhysicsBody(rectangleOf: blockNode.size)
                blockNode.physicsBody?.isDynamic = false
                blockNode.physicsBody?.categoryBitMask = obstacleCategory
                blockNode.physicsBody?.contactTestBitMask = playerCategory
                blockNode.physicsBody?.collisionBitMask = 0
                
                rowNode.addChild(blockNode)
            }
        }
        
        addChild(rowNode)
        
        // Move obstacle down
        let moveDown = SKAction.moveTo(y: -obstacleHeight, duration: obstacleDuration)
        let remove = SKAction.removeFromParent()
        rowNode.run(SKAction.sequence([moveDown, remove]))
    }
    
    // MARK: - Input Handling
    
    private var activeSafeLane: Int? {
        if isWaitingForCorrectAnswer {
            return safeLaneForStuckRow
        }
        
        var nearestRow: SKNode? = nil
        var minDistance: CGFloat = .greatestFiniteMagnitude
        let playerY = size.height * playerYPositionMultiplier
        
        enumerateChildNodes(withName: "obstacleRow") { node, _ in
            let distance = node.position.y - playerY
            // Only consider obstacles that haven't fully passed the player
            if distance > -20 && distance < minDistance {
                minDistance = distance
                nearestRow = node
            }
        }
        
        return nearestRow?.userData?["safeLane"] as? Int
    }
    
    func changeLane(to chord: String) {
        guard let safeLane = activeSafeLane else { return }
        
        // Determine the correct chord for the safe lane
        var correctChords: [String] = []
        switch safeLane {
        case 0: correctChords = ["C"]
        case 1: correctChords = ["D"]
        case 2: correctChords = ["Am", "A"]
        case 3: correctChords = ["G"]
        default: return
        }
        
        // Only move if the detected chord is the correct one for the upcoming obstacle
        if correctChords.contains(chord) {
            if currentLane != safeLane {
                currentLane = safeLane
                let targetX = (CGFloat(safeLane) + 0.5) * laneWidth
                
                isSliding = true
                let moveAction = SKAction.moveTo(x: targetX, duration: 0.15) // Slightly increased duration for smoother slide
                let finishSliding = SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.isSliding = false
                    
                    // If we were frozen from a collision, resume AFTER we finish sliding!
                    if self.isWaitingForCorrectAnswer {
                        self.resumeFromCollision()
                    }
                }
                player.run(SKAction.sequence([moveAction, finishSliding]))
            }
        }
    }
    
    private func positionFor(lane: Int, y: CGFloat) -> CGPoint {
        let x = (CGFloat(lane) + 0.5) * laneWidth
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Collision Handling
    
    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if collision == (playerCategory | obstacleCategory) {
            // Hit an obstacle, stop and wait
            if !isWaitingForCorrectAnswer && !isSliding {
                let obstacleNode = contact.bodyA.categoryBitMask == obstacleCategory ? contact.bodyA.node : contact.bodyB.node
                if let rowNode = obstacleNode?.parent {
                    handleCollision(with: rowNode)
                }
            }
        } else if collision == (playerCategory | scoreCategory) {
            // Passed through a safe gap
            // Ensure we only score once per row
            if let nodeA = contact.bodyA.node, let nodeB = contact.bodyB.node {
                let scoreNode = contact.bodyA.categoryBitMask == scoreCategory ? nodeA : nodeB
                // Remove the score node so it doesn't trigger again
                scoreNode.removeFromParent()
                score += 1
            }
        }
    }
    
    private func handleCollision(with rowNode: SKNode) {
        isWaitingForCorrectAnswer = true
        stuckRowNode = rowNode
        safeLaneForStuckRow = rowNode.userData?["safeLane"] as? Int
        
        // Pause all obstacle rows
        enumerateChildNodes(withName: "obstacleRow") { node, _ in
            node.isPaused = true
        }
    }
    
    private func resumeFromCollision() {
        isWaitingForCorrectAnswer = false
        stuckRowNode = nil
        safeLaneForStuckRow = nil
        
        // Unpause all obstacle rows
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
        player.position = positionFor(lane: currentLane, y: size.height * playerYPositionMultiplier)
    }
    
    private func gameOver() {
        // Simple game over: pause and show label
        isPaused = true
        
        let gameOverLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        gameOverLabel.fontSize = 40
        gameOverLabel.fontColor = .systemRed
        gameOverLabel.text = "Game Over!"
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        gameOverLabel.zPosition = 100
        addChild(gameOverLabel)
        
        // Tap to restart could be added
    }
}
