import DomainVision
import SudokuDomain

struct DetailedPredictionCorrectionResult: Equatable {
    let correctedBoard: [[Int]]
    let solvedBoard: [[Int]]
}

enum DetailedPredictionCorrection {
    private enum Config {
        static let maximumCells = 6
        static let maximumChoicesPerCell = 2
        static let lowConfidenceCutoff = 0.84
        static let lowConfidenceMargin = 0.12
        static let blankingMarginCutoff = 0.18
        static let maximumCombinationCount = 64
        static let iterationLimit = 250_000
    }

    static func solveIfNeeded(
        board: [[Int]],
        details: [SudokuDigitPredictionDetail],
        solver: SudokuSolver
    ) -> DetailedPredictionCorrectionResult? {
        let candidates = makeCandidates(board: board, details: details)
        guard !candidates.isEmpty else { return nil }

        let combinationLimit = min(Config.maximumCombinationCount, 1 << candidates.count)
        for changeCount in 1...candidates.count {
            for mask in 1..<combinationLimit where mask.nonzeroBitCount == changeCount {
                var candidateBoard = board
                for (candidateIndex, candidate) in candidates.enumerated() {
                    let useAlternative = ((mask >> candidateIndex) & 1) == 1
                    candidateBoard[candidate.row][candidate.col] = useAlternative ? candidate.choices[1] : candidate.choices[0]
                }

                switch solver.solve(candidateBoard, iterationLimit: Config.iterationLimit) {
                case .success(let solvedBoard):
                    return DetailedPredictionCorrectionResult(
                        correctedBoard: candidateBoard,
                        solvedBoard: solvedBoard
                    )
                case .failure:
                    continue
                }
            }
        }

        return nil
    }

    private static func makeCandidates(
        board: [[Int]],
        details: [SudokuDigitPredictionDetail]
    ) -> [Candidate] {
        guard board.count == 9, details.count == 81 else { return [] }
        let conflictIndices = conflictingCellIndices(in: board)

        return details.enumerated()
            .compactMap { index, detail -> Candidate? in
                let row = index / 9
                let col = index % 9
                let currentDigit = board[row][col]
                let isConflicting = conflictIndices.contains(index)
                guard currentDigit != 0 else { return nil }

                let choices = makeChoices(
                    currentDigit: currentDigit,
                    detail: detail,
                    isConflicting: isConflicting
                )
                guard choices.count > 1 else { return nil }
                let ambiguity = detail.confidence - (detail.alternatives.first?.confidence ?? 0)
                guard isConflicting
                    || detail.confidence < Config.lowConfidenceCutoff
                    || ambiguity < Config.lowConfidenceMargin
                    || detail.isBlankLikely else {
                    return nil
                }

                return Candidate(
                    row: row,
                    col: col,
                    choices: choices,
                    priority: detail.confidence
                        - max(0, Config.lowConfidenceMargin - ambiguity)
                        - (isConflicting ? 0.24 : 0)
                )
            }
            .sorted {
                if $0.priority == $1.priority {
                    if $0.row == $1.row {
                        return $0.col < $1.col
                    }
                    return $0.row < $1.row
                }
                return $0.priority < $1.priority
            }
            .prefix(Config.maximumCells)
            .map { $0 }
    }

    private static func makeChoices(
        currentDigit: Int,
        detail: SudokuDigitPredictionDetail,
        isConflicting: Bool
    ) -> [Int] {
        var choices = [currentDigit]
        var alternatives: [(digit: Int, score: Double)] = []

        let ambiguity = detail.confidence - (detail.alternatives.first?.confidence ?? 0)
        if isConflicting
            || detail.isBlankLikely
            || detail.confidence < Config.lowConfidenceCutoff
            || ambiguity < Config.blankingMarginCutoff {
            let blankScore = blankChoiceScore(detail: detail, isConflicting: isConflicting)
            alternatives.append((digit: 0, score: blankScore))
        }

        for alternative in detail.alternatives {
            guard (1...9).contains(alternative.digit) else { continue }
            guard alternative.digit != currentDigit else { continue }
            var score = alternative.confidence
            if isConflicting { score += 0.05 }
            alternatives.append((digit: alternative.digit, score: score))
        }

        if let bestAlternative = alternatives.sorted(by: {
            if $0.score == $1.score {
                return $0.digit < $1.digit
            }
            return $0.score > $1.score
        }).first {
            choices.append(bestAlternative.digit)
        }

        return Array(choices.prefix(Config.maximumChoicesPerCell))
    }

    private static func blankChoiceScore(
        detail: SudokuDigitPredictionDetail,
        isConflicting: Bool
    ) -> Double {
        var score = isConflicting ? 0.78 : 0.50
        if detail.isBlankLikely { score += 0.18 }
        if detail.confidence < Config.lowConfidenceCutoff { score += 0.16 }
        let ambiguity = detail.confidence - (detail.alternatives.first?.confidence ?? 0)
        if ambiguity < Config.blankingMarginCutoff { score += 0.12 }
        return score
    }

    private static func conflictingCellIndices(in board: [[Int]]) -> Set<Int> {
        guard board.count == 9, board.allSatisfy({ $0.count == 9 }) else { return [] }

        var conflicts = Set<Int>()

        for row in 0..<9 {
            var rowPositions: [Int: [Int]] = [:]
            var colPositions: [Int: [Int]] = [:]

            for col in 0..<9 {
                let rowValue = board[row][col]
                if rowValue != 0 {
                    rowPositions[rowValue, default: []].append((row * 9) + col)
                }

                let colValue = board[col][row]
                if colValue != 0 {
                    colPositions[colValue, default: []].append((col * 9) + row)
                }
            }

            insertConflicts(from: rowPositions, into: &conflicts)
            insertConflicts(from: colPositions, into: &conflicts)
        }

        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                var boxPositions: [Int: [Int]] = [:]
                for row in boxRow..<(boxRow + 3) {
                    for col in boxCol..<(boxCol + 3) {
                        let value = board[row][col]
                        if value == 0 { continue }
                        boxPositions[value, default: []].append((row * 9) + col)
                    }
                }
                insertConflicts(from: boxPositions, into: &conflicts)
            }
        }

        return conflicts
    }

    private static func insertConflicts(from positions: [Int: [Int]], into conflicts: inout Set<Int>) {
        for indices in positions.values where indices.count > 1 {
            conflicts.formUnion(indices)
        }
    }

    private struct Candidate: Equatable {
        let row: Int
        let col: Int
        let choices: [Int]
        let priority: Double
    }
}
