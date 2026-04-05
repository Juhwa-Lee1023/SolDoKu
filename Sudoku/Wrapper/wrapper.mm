//
//  wrapper.mm
//  Sudoku
//
//  Created by 이주화 on 2022/09/12.
//

#import "wrapper.h"
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <algorithm>
#import <array>
#import <cfloat>
#import <cmath>
#import <numeric>
#import <optional>

#ifdef __cplusplus
#undef NO
#undef YES
#endif

namespace {

struct VisionConfig {
    static constexpr int warpedBoardSize = 900;
    static constexpr double minBoardAreaRatio = 0.18;
    static constexpr double minimumRescuableBoardAreaRatio = 0.05;
    static constexpr double maxAspectDeviation = 0.38;
    static constexpr double minCandidateAcceptanceScore = 0.55;
    static constexpr double rescuedCandidateAcceptanceScore = 0.5;
    static constexpr double borderMarginRatio = 0.025;
    static constexpr double maxCenterDistanceRatio = 0.6;
    static constexpr double minGridConfidence = 0.4;
    static constexpr double strongSmallBoardGridConfidence = 0.72;
    static constexpr double strongSmallBoardRightAngleScore = 0.82;
    static constexpr double strongSmallBoardCenterScore = 0.08;
    static constexpr double blankInkRatioThreshold = 0.018;
    static constexpr double minComponentAreaRatio = 0.0022;
    static constexpr double maxComponentCentroidDistanceRatio = 0.42;
    static constexpr int boardBlurKernelSize = 5;
    static constexpr int adaptiveThresholdBlockSize = 31;
    static constexpr int adaptiveThresholdConstant = 9;
    static constexpr double cannyLowThreshold = 60.0;
    static constexpr double cannyHighThreshold = 160.0;
    static constexpr double contourApproximationRatio = 0.02;
    static constexpr double contourApproximationFallbackRatio = 0.04;
    static constexpr double candidateAngleCosineClamp = 0.4;
    static constexpr double gridSearchWindowRatio = 0.08;
    static constexpr double cellBorderMaskRatio = 0.08;
    static constexpr double cellPaddingRatio = 0.2;
};

struct GridBoundaries {
    std::array<int, 10> vertical {};
    std::array<int, 10> horizontal {};
    double confidence = 0;
    bool refined = false;
};

struct BoardCandidate {
    std::vector<cv::Point2f> corners;
    cv::Mat warpedBoard;
    GridBoundaries boundaries;
    double areaRatio = 0;
    double aspectDeviation = 1;
    double rightAngleScore = 0;
    double centerScore = 0;
    double borderScore = 0;
    double gridScore = 0;
    double totalScore = 0;
};

struct CellAnalysis {
    bool hasMeaningfulInk = false;
    cv::Mat normalizedDigit;
    double inkRatio = 0;
    double componentAreaRatio = 0;
    double centroidDistanceRatio = 1;
    bool touchesBorder = false;
    cv::Mat debugImage;
};

double distanceBetween(const cv::Point2f &lhs, const cv::Point2f &rhs) {
    const double dx = lhs.x - rhs.x;
    const double dy = lhs.y - rhs.y;
    return std::sqrt((dx * dx) + (dy * dy));
}

cv::Mat ensureGrayscale(const cv::Mat &input) {
    cv::Mat gray;
    if (input.channels() == 1) {
        gray = input.clone();
    } else if (input.channels() == 4) {
        cv::cvtColor(input, gray, cv::COLOR_BGRA2GRAY);
    } else {
        cv::cvtColor(input, gray, cv::COLOR_BGR2GRAY);
    }
    return gray;
}

cv::Mat normalizeBoardGray(const cv::Mat &inputGray) {
    cv::Mat blurred;
    cv::GaussianBlur(inputGray, blurred, cv::Size(VisionConfig::boardBlurKernelSize, VisionConfig::boardBlurKernelSize), 0);

    cv::Mat normalized;
    auto clahe = cv::createCLAHE(2.0, cv::Size(8, 8));
    clahe->apply(blurred, normalized);
    return normalized;
}

cv::Mat binaryMaskFromAdaptive(const cv::Mat &gray) {
    cv::Mat mask;
    cv::adaptiveThreshold(
        gray,
        mask,
        255,
        cv::ADAPTIVE_THRESH_GAUSSIAN_C,
        cv::THRESH_BINARY_INV,
        VisionConfig::adaptiveThresholdBlockSize,
        VisionConfig::adaptiveThresholdConstant
    );
    cv::morphologyEx(mask, mask, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));
    return mask;
}

cv::Mat binaryMaskFromOtsuAndEdges(const cv::Mat &gray) {
    cv::Mat otsuMask;
    cv::threshold(gray, otsuMask, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);

    cv::Mat edges;
    cv::Canny(gray, edges, VisionConfig::cannyLowThreshold, VisionConfig::cannyHighThreshold);
    cv::dilate(edges, edges, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));

    cv::Mat combined;
    cv::bitwise_or(otsuMask, edges, combined);
    cv::morphologyEx(combined, combined, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(5, 5)));
    return combined;
}

cv::Mat binaryMaskFromGridLines(const cv::Mat &gray) {
    cv::Mat adaptive = binaryMaskFromAdaptive(gray);
    const int minimumDimension = std::max(1, std::min(gray.cols, gray.rows));
    const int kernelLength = std::max(18, minimumDimension / 14);

    cv::Mat verticalLines;
    cv::morphologyEx(
        adaptive,
        verticalLines,
        cv::MORPH_OPEN,
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, kernelLength))
    );

    cv::Mat horizontalLines;
    cv::morphologyEx(
        adaptive,
        horizontalLines,
        cv::MORPH_OPEN,
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(kernelLength, 1))
    );

    cv::Mat gridMask;
    cv::bitwise_or(verticalLines, horizontalLines, gridMask);
    cv::morphologyEx(gridMask, gridMask, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(5, 5)));
    cv::dilate(gridMask, gridMask, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(3, 3)));
    return gridMask;
}

std::vector<cv::Mat> buildBoardCandidateMasks(const cv::Mat &gray) {
    std::vector<cv::Mat> masks;
    masks.push_back(binaryMaskFromAdaptive(gray));
    masks.push_back(binaryMaskFromOtsuAndEdges(gray));
    masks.push_back(binaryMaskFromGridLines(gray));

    cv::Mat medianBlurred;
    cv::medianBlur(gray, medianBlurred, 5);
    masks.push_back(binaryMaskFromAdaptive(medianBlurred));
    masks.push_back(binaryMaskFromGridLines(medianBlurred));
    return masks;
}

std::vector<cv::Point2f> orderBoardCorners(const std::vector<cv::Point2f> &corners) {
    if (corners.size() != 4) {
        return {};
    }

    std::vector<cv::Point2f> ordered = corners;
    std::sort(ordered.begin(), ordered.end(), [](const cv::Point2f &lhs, const cv::Point2f &rhs) {
        if (lhs.y == rhs.y) {
            return lhs.x < rhs.x;
        }
        return lhs.y < rhs.y;
    });

    std::vector<cv::Point2f> top(ordered.begin(), ordered.begin() + 2);
    std::vector<cv::Point2f> bottom(ordered.begin() + 2, ordered.end());
    std::sort(top.begin(), top.end(), [](const cv::Point2f &lhs, const cv::Point2f &rhs) { return lhs.x < rhs.x; });
    std::sort(bottom.begin(), bottom.end(), [](const cv::Point2f &lhs, const cv::Point2f &rhs) { return lhs.x < rhs.x; });

    return { top[0], top[1], bottom[1], bottom[0] };
}

cv::Mat warpBoardToSquare(const cv::Mat &source, const std::vector<cv::Point2f> &orderedCorners) {
    const float maxCoordinate = static_cast<float>(VisionConfig::warpedBoardSize - 1);
    std::vector<cv::Point2f> destination = {
        cv::Point2f(0, 0),
        cv::Point2f(maxCoordinate, 0),
        cv::Point2f(maxCoordinate, maxCoordinate),
        cv::Point2f(0, maxCoordinate),
    };

    cv::Mat transform = cv::getPerspectiveTransform(orderedCorners, destination);
    cv::Mat warped;
    cv::warpPerspective(
        source,
        warped,
        transform,
        cv::Size(VisionConfig::warpedBoardSize, VisionConfig::warpedBoardSize),
        cv::INTER_LINEAR,
        cv::BORDER_REPLICATE
    );
    return warped;
}

std::array<int, 10> makeUniformBoundaries(int size) {
    std::array<int, 10> boundaries {};
    for (int index = 0; index < 10; index++) {
        boundaries[index] = static_cast<int>(std::round((size - 1) * (static_cast<double>(index) / 9.0)));
    }
    boundaries[0] = 0;
    boundaries[9] = size - 1;
    return boundaries;
}

std::vector<double> projectionValuesForMat(const cv::Mat &mask, int dimension) {
    cv::Mat projection;
    cv::reduce(mask, projection, dimension, cv::REDUCE_SUM, CV_64F);

    std::vector<double> values;
    values.reserve(static_cast<size_t>(dimension == 0 ? projection.cols : projection.rows));
    if (dimension == 0) {
        for (int col = 0; col < projection.cols; col++) {
            values.push_back(projection.at<double>(0, col));
        }
    } else {
        for (int row = 0; row < projection.rows; row++) {
            values.push_back(projection.at<double>(row, 0));
        }
    }
    return values;
}

std::array<int, 10> refineAxisBoundaries(
    const std::vector<double> &projection,
    int size,
    double *averageConfidence
) {
    auto boundaries = makeUniformBoundaries(size);
    if (projection.empty()) {
        *averageConfidence = 0;
        return boundaries;
    }

    const double maxProjection = *std::max_element(projection.begin(), projection.end());
    if (maxProjection <= 0) {
        *averageConfidence = 0;
        return boundaries;
    }

    const int searchWindow = std::max(8, static_cast<int>(std::round(size * VisionConfig::gridSearchWindowRatio)));
    const int minimumGap = std::max(4, size / 16);

    double confidenceSum = 0;
    for (int index = 0; index < 10; index++) {
        const int expected = boundaries[index];
        const int start = std::max(0, expected - searchWindow);
        const int end = std::min(size - 1, expected + searchWindow);

        int bestPosition = expected;
        double bestValue = -1;
        for (int position = start; position <= end; position++) {
            const double value = projection[static_cast<size_t>(position)];
            if (value > bestValue) {
                bestValue = value;
                bestPosition = position;
            }
        }

        const double normalizedStrength = std::clamp(bestValue / maxProjection, 0.0, 1.0);
        confidenceSum += normalizedStrength;
        boundaries[index] = bestPosition;
    }

    boundaries[0] = 0;
    boundaries[9] = size - 1;
    for (int index = 1; index < 10; index++) {
        if (boundaries[index] <= boundaries[index - 1]) {
            boundaries[index] = boundaries[index - 1] + minimumGap;
        }
    }

    for (int index = 8; index >= 0; index--) {
        if (boundaries[index] >= boundaries[index + 1]) {
            boundaries[index] = boundaries[index + 1] - minimumGap;
        }
    }

    for (int index = 0; index < 10; index++) {
        boundaries[index] = std::clamp(boundaries[index], 0, size - 1);
    }
    boundaries[0] = 0;
    boundaries[9] = size - 1;
    *averageConfidence = confidenceSum / 10.0;
    return boundaries;
}

GridBoundaries refineGridBoundaries(const cv::Mat &warpedBoard) {
    GridBoundaries grid;
    const int size = warpedBoard.cols;
    grid.vertical = makeUniformBoundaries(size);
    grid.horizontal = makeUniformBoundaries(warpedBoard.rows);

    cv::Mat gray = ensureGrayscale(warpedBoard);
    cv::Mat normalized = normalizeBoardGray(gray);

    cv::Mat binary = binaryMaskFromAdaptive(normalized);
    const int lineKernelLength = std::max(15, size / 14);

    cv::Mat verticalLines;
    cv::morphologyEx(
        binary,
        verticalLines,
        cv::MORPH_OPEN,
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(1, lineKernelLength))
    );

    cv::Mat horizontalLines;
    cv::morphologyEx(
        binary,
        horizontalLines,
        cv::MORPH_OPEN,
        cv::getStructuringElement(cv::MORPH_RECT, cv::Size(lineKernelLength, 1))
    );

    double verticalConfidence = 0;
    double horizontalConfidence = 0;
    grid.vertical = refineAxisBoundaries(projectionValuesForMat(verticalLines, 0), size, &verticalConfidence);
    grid.horizontal = refineAxisBoundaries(projectionValuesForMat(horizontalLines, 1), size, &horizontalConfidence);
    grid.confidence = std::min(verticalConfidence, horizontalConfidence);
    grid.refined = grid.confidence >= VisionConfig::minGridConfidence;

    if (!grid.refined) {
        grid.vertical = makeUniformBoundaries(size);
        grid.horizontal = makeUniformBoundaries(warpedBoard.rows);
    }

    return grid;
}

double rightAngleScoreForCorners(const std::vector<cv::Point2f> &corners) {
    if (corners.size() != 4) {
        return 0;
    }

    double scoreSum = 0;
    for (int index = 0; index < 4; index++) {
        const cv::Point2f previous = corners[(index + 3) % 4];
        const cv::Point2f current = corners[index];
        const cv::Point2f next = corners[(index + 1) % 4];

        const cv::Point2f lhs = previous - current;
        const cv::Point2f rhs = next - current;
        const double lhsLength = std::sqrt(lhs.x * lhs.x + lhs.y * lhs.y);
        const double rhsLength = std::sqrt(rhs.x * rhs.x + rhs.y * rhs.y);
        if (lhsLength <= 0 || rhsLength <= 0) {
            return 0;
        }

        const double cosine = std::abs((lhs.x * rhs.x + lhs.y * rhs.y) / (lhsLength * rhsLength));
        scoreSum += 1.0 - std::clamp(cosine / VisionConfig::candidateAngleCosineClamp, 0.0, 1.0);
    }
    return scoreSum / 4.0;
}

double centerAlignmentScore(const std::vector<cv::Point2f> &corners, const cv::Size &imageSize) {
    cv::Point2f candidateCenter(0, 0);
    for (const auto &corner : corners) {
        candidateCenter += corner;
    }
    candidateCenter *= 0.25f;

    const cv::Point2f imageCenter(imageSize.width * 0.5f, imageSize.height * 0.5f);
    const double distance = distanceBetween(candidateCenter, imageCenter);
    const double maximumDistance = std::sqrt((imageSize.width * imageSize.width) + (imageSize.height * imageSize.height)) * 0.5;
    if (maximumDistance <= 0) {
        return 0;
    }

    return 1.0 - std::clamp(distance / (maximumDistance * VisionConfig::maxCenterDistanceRatio), 0.0, 1.0);
}

double borderContainmentScore(const std::vector<cv::Point2f> &corners, const cv::Size &imageSize) {
    const double xMargin = imageSize.width * VisionConfig::borderMarginRatio;
    const double yMargin = imageSize.height * VisionConfig::borderMarginRatio;
    double penalty = 0;

    for (const auto &corner : corners) {
        if (corner.x <= xMargin || corner.x >= imageSize.width - xMargin) {
            penalty += 0.22;
        }
        if (corner.y <= yMargin || corner.y >= imageSize.height - yMargin) {
            penalty += 0.22;
        }
    }

    return std::clamp(1.0 - penalty, 0.0, 1.0);
}

double totalCandidateScore(
    double areaRatio,
    double aspectDeviation,
    double rightAngleScore,
    double centerScore,
    double borderScore,
    double gridScore
) {
    const double areaScore = std::clamp(
        (areaRatio - VisionConfig::minimumRescuableBoardAreaRatio) / 0.45,
        0.0,
        1.0
    );
    const double aspectScore = 1.0 - std::clamp(aspectDeviation / VisionConfig::maxAspectDeviation, 0.0, 1.0);
    const double suspiciousCoveragePenalty = areaRatio > 0.94
        ? std::clamp((areaRatio - 0.94) * (1.0 - gridScore) * 2.5, 0.0, 0.22)
        : 0.0;
    const double smallBoardPenalty = areaRatio < VisionConfig::minBoardAreaRatio
        ? std::clamp(
            (VisionConfig::minBoardAreaRatio - areaRatio) * (1.15 - (gridScore * 0.7)) * 1.6,
            0.0,
            0.18
        )
        : 0.0;

    return ((areaScore * 0.22)
        + (aspectScore * 0.16)
        + (rightAngleScore * 0.16)
        + (centerScore * 0.1)
        + (borderScore * 0.08)
        + (gridScore * 0.28))
        - suspiciousCoveragePenalty
        - smallBoardPenalty;
}

std::vector<cv::Point> approximateQuadrilateral(const std::vector<cv::Point> &contour) {
    const double perimeter = cv::arcLength(contour, true);
    std::vector<cv::Point> approximation;
    cv::approxPolyDP(contour, approximation, VisionConfig::contourApproximationRatio * perimeter, true);
    if (approximation.size() == 4 && cv::isContourConvex(approximation)) {
        return approximation;
    }

    std::vector<cv::Point> convex;
    cv::convexHull(contour, convex);
    cv::approxPolyDP(convex, approximation, VisionConfig::contourApproximationFallbackRatio * perimeter, true);
    if (approximation.size() == 4 && cv::isContourConvex(approximation)) {
        return approximation;
    }

    return {};
}

double polygonArea(const std::vector<cv::Point2f> &corners) {
    if (corners.size() < 4) {
        return 0;
    }

    double sum = 0;
    for (size_t index = 0; index < corners.size(); index++) {
        const auto &current = corners[index];
        const auto &next = corners[(index + 1) % corners.size()];
        sum += (current.x * next.y) - (next.x * current.y);
    }
    return std::abs(sum) * 0.5;
}

std::optional<BoardCandidate> makeBoardCandidateFromCorners(const cv::Mat &source, std::vector<cv::Point2f> corners) {
    const double imageArea = static_cast<double>(source.cols * source.rows);
    if (imageArea <= 0) {
        return std::nullopt;
    }

    corners = orderBoardCorners(corners);
    if (corners.size() != 4) {
        return std::nullopt;
    }

    const double areaRatio = polygonArea(corners) / imageArea;
    if (areaRatio < VisionConfig::minimumRescuableBoardAreaRatio) {
        return std::nullopt;
    }

    const double topWidth = distanceBetween(corners[0], corners[1]);
    const double bottomWidth = distanceBetween(corners[3], corners[2]);
    const double leftHeight = distanceBetween(corners[0], corners[3]);
    const double rightHeight = distanceBetween(corners[1], corners[2]);
    const double averageWidth = (topWidth + bottomWidth) * 0.5;
    const double averageHeight = (leftHeight + rightHeight) * 0.5;
    const double longestSide = std::max(averageWidth, averageHeight);
    const double shortestSide = std::max(1.0, std::min(averageWidth, averageHeight));
    const double aspectDeviation = std::abs(longestSide - shortestSide) / longestSide;
    if (aspectDeviation > VisionConfig::maxAspectDeviation) {
        return std::nullopt;
    }

    const double rightAngleScore = rightAngleScoreForCorners(corners);
    const double centerScore = centerAlignmentScore(corners, source.size());
    const double borderScore = borderContainmentScore(corners, source.size());

    cv::Mat warpedBoard = warpBoardToSquare(source, corners);
    GridBoundaries boundaries = refineGridBoundaries(warpedBoard);
    const double gridScore = boundaries.refined ? boundaries.confidence : boundaries.confidence * 0.6;
    const bool rescuedSmallBoard = areaRatio < VisionConfig::minBoardAreaRatio;
    if (rescuedSmallBoard
        && (gridScore < VisionConfig::strongSmallBoardGridConfidence
            || rightAngleScore < VisionConfig::strongSmallBoardRightAngleScore
            || centerScore < VisionConfig::strongSmallBoardCenterScore)) {
        return std::nullopt;
    }

    BoardCandidate candidate;
    candidate.corners = std::move(corners);
    candidate.warpedBoard = std::move(warpedBoard);
    candidate.boundaries = boundaries;
    candidate.areaRatio = areaRatio;
    candidate.aspectDeviation = aspectDeviation;
    candidate.rightAngleScore = rightAngleScore;
    candidate.centerScore = centerScore;
    candidate.borderScore = borderScore;
    candidate.gridScore = gridScore;
    candidate.totalScore = totalCandidateScore(areaRatio, aspectDeviation, rightAngleScore, centerScore, borderScore, gridScore);
    return candidate;
}

std::optional<BoardCandidate> makeBoardCandidate(const cv::Mat &source, const std::vector<cv::Point> &contour) {
    const double contourAreaValue = std::abs(cv::contourArea(contour));
    const double imageArea = static_cast<double>(source.cols * source.rows);
    if (imageArea <= 0) {
        return std::nullopt;
    }

    const double areaRatio = contourAreaValue / imageArea;
    if (areaRatio < VisionConfig::minimumRescuableBoardAreaRatio) {
        return std::nullopt;
    }

    const auto quadrilateral = approximateQuadrilateral(contour);
    if (quadrilateral.size() != 4) {
        return std::nullopt;
    }

    std::vector<cv::Point2f> corners;
    corners.reserve(4);
    for (const auto &point : quadrilateral) {
        corners.push_back(cv::Point2f(point.x, point.y));
    }
    return makeBoardCandidateFromCorners(source, corners);
}

std::optional<BoardCandidate> detectBestBoardCandidate(const cv::Mat &source) {
    cv::Mat gray = ensureGrayscale(source);
    cv::Mat normalizedGray = normalizeBoardGray(gray);
    auto masks = buildBoardCandidateMasks(normalizedGray);

    std::vector<BoardCandidate> candidates;
    for (const auto &mask : masks) {
        std::vector<std::vector<cv::Point>> contours;
        cv::findContours(mask.clone(), contours, cv::RETR_LIST, cv::CHAIN_APPROX_SIMPLE);

        for (const auto &contour : contours) {
            if (contour.size() < 4) {
                continue;
            }
            auto candidate = makeBoardCandidate(source, contour);
            if (candidate.has_value()) {
                candidates.push_back(std::move(candidate.value()));
            }
        }
    }

    if (candidates.empty()) {
        return std::nullopt;
    }

    std::sort(candidates.begin(), candidates.end(), [](const BoardCandidate &lhs, const BoardCandidate &rhs) {
        return lhs.totalScore > rhs.totalScore;
    });

    const auto &bestCandidate = candidates.front();
    const bool rescuedSmallBoard = bestCandidate.areaRatio < VisionConfig::minBoardAreaRatio;
    const double minimumAcceptanceScore = rescuedSmallBoard
        ? VisionConfig::rescuedCandidateAcceptanceScore
        : VisionConfig::minCandidateAcceptanceScore;
    if (bestCandidate.totalScore < minimumAcceptanceScore) {
        return std::nullopt;
    }
    return bestCandidate;
}

NSArray *pointArrayFromCorners(const std::vector<cv::Point2f> &corners) {
    NSMutableArray *points = [[NSMutableArray alloc] initWithCapacity:corners.size()];
    for (const auto &corner : corners) {
        [points addObject:[NSValue valueWithCGPoint:CGPointMake(corner.x, corner.y)]];
    }
    return points;
}

cv::Rect symmetricInsetRect(const cv::Rect &baseRect, int cutOffset, const cv::Size &imageSize) {
    const int maxInsetX = std::max(0, (baseRect.width - 2) / 2);
    const int maxInsetY = std::max(0, (baseRect.height - 2) / 2);
    const int inset = std::max(0, std::min(cutOffset, std::min(maxInsetX, maxInsetY)));

    cv::Rect insetRect(
        baseRect.x + inset,
        baseRect.y + inset,
        std::max(1, baseRect.width - (inset * 2)),
        std::max(1, baseRect.height - (inset * 2))
    );
    insetRect &= cv::Rect(0, 0, imageSize.width, imageSize.height);
    if (insetRect.width <= 0 || insetRect.height <= 0) {
        return baseRect & cv::Rect(0, 0, imageSize.width, imageSize.height);
    }
    return insetRect;
}

cv::Mat rgbaMatFromGray(const cv::Mat &gray) {
    cv::Mat rgba;
    cv::cvtColor(gray, rgba, cv::COLOR_GRAY2RGBA);
    return rgba;
}

cv::Mat normalizeCellGray(const cv::Mat &source) {
    cv::Mat gray = ensureGrayscale(source);
    cv::Mat normalized;
    auto clahe = cv::createCLAHE(2.0, cv::Size(8, 8));
    clahe->apply(gray, normalized);
    return normalized;
}

cv::Mat chooseCellBinaryMask(const cv::Mat &normalizedGray) {
    cv::Mat adaptive = cv::Mat::zeros(normalizedGray.size(), CV_8UC1);
    const int minimumSide = std::max(3, std::min(normalizedGray.cols, normalizedGray.rows));
    const int maximumOddBlockSize = minimumSide % 2 == 0 ? minimumSide - 1 : minimumSide;
    const int blockSize = std::max(3, std::min(31, maximumOddBlockSize));
    cv::adaptiveThreshold(
        normalizedGray,
        adaptive,
        255,
        cv::ADAPTIVE_THRESH_GAUSSIAN_C,
        cv::THRESH_BINARY_INV,
        blockSize,
        7
    );

    cv::Mat otsu;
    cv::threshold(normalizedGray, otsu, 0, 255, cv::THRESH_BINARY_INV | cv::THRESH_OTSU);

    const double adaptiveInk = static_cast<double>(cv::countNonZero(adaptive));
    const double otsuInk = static_cast<double>(cv::countNonZero(otsu));
    cv::Mat selected = (adaptiveInk > 0 && adaptiveInk < otsuInk * 1.6) ? adaptive : otsu;
    cv::morphologyEx(selected, selected, cv::MORPH_OPEN, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(2, 2)));
    return selected;
}

CellAnalysis analyzeCellMat(const cv::Mat &source, int imageSize, bool generateDebugImage) {
    CellAnalysis analysis;
    if (source.empty()) {
        return analysis;
    }

    cv::Mat normalizedGray = normalizeCellGray(source);
    cv::Mat binary = chooseCellBinaryMask(normalizedGray);

    const int borderInsetX = std::max(1, static_cast<int>(std::round(binary.cols * VisionConfig::cellBorderMaskRatio)));
    const int borderInsetY = std::max(1, static_cast<int>(std::round(binary.rows * VisionConfig::cellBorderMaskRatio)));
    cv::Rect focusRect(
        borderInsetX,
        borderInsetY,
        std::max(1, binary.cols - (borderInsetX * 2)),
        std::max(1, binary.rows - (borderInsetY * 2))
    );
    focusRect &= cv::Rect(0, 0, binary.cols, binary.rows);
    cv::Mat focusMask = binary(focusRect).clone();

    cv::Mat labels;
    cv::Mat stats;
    cv::Mat centroids;
    const int labelCount = cv::connectedComponentsWithStats(focusMask, labels, stats, centroids, 8, CV_32S);
    if (labelCount <= 1) {
        if (generateDebugImage) {
            analysis.debugImage = rgbaMatFromGray(255 - focusMask);
        }
        return analysis;
    }

    const double focusArea = static_cast<double>(focusMask.cols * focusMask.rows);
    int bestLabel = -1;
    double bestScore = -DBL_MAX;
    cv::Rect bestRect;

    for (int label = 1; label < labelCount; label++) {
        const int area = stats.at<int>(label, cv::CC_STAT_AREA);
        if (area <= 0) {
            continue;
        }

        cv::Rect rect(
            stats.at<int>(label, cv::CC_STAT_LEFT),
            stats.at<int>(label, cv::CC_STAT_TOP),
            stats.at<int>(label, cv::CC_STAT_WIDTH),
            stats.at<int>(label, cv::CC_STAT_HEIGHT)
        );
        const double areaRatio = area / focusArea;
        const bool touchesBorder = rect.x <= 1
            || rect.y <= 1
            || rect.x + rect.width >= focusMask.cols - 1
            || rect.y + rect.height >= focusMask.rows - 1;

        const cv::Point2d centroid(centroids.at<double>(label, 0), centroids.at<double>(label, 1));
        const cv::Point2d focusCenter(focusMask.cols * 0.5, focusMask.rows * 0.5);
        const double dx = centroid.x - focusCenter.x;
        const double dy = centroid.y - focusCenter.y;
        const double centroidDistance = std::sqrt((dx * dx) + (dy * dy));
        const double centroidDistanceRatio = centroidDistance / std::max(1.0, std::sqrt((focusMask.cols * focusMask.cols) + (focusMask.rows * focusMask.rows)) * 0.5);

        const double compactnessPenalty = (rect.width == 0 || rect.height == 0)
            ? 1.0
            : std::abs((static_cast<double>(rect.width) / rect.height) - 1.0) * 0.05;
        const double score = (areaRatio * 1.8)
            - (centroidDistanceRatio * 0.6)
            - (touchesBorder ? 0.32 : 0.0)
            - compactnessPenalty;

        if (score > bestScore) {
            bestScore = score;
            bestLabel = label;
            bestRect = rect;
        }
    }

    if (bestLabel < 0) {
        if (generateDebugImage) {
            analysis.debugImage = rgbaMatFromGray(255 - focusMask);
        }
        return analysis;
    }

    cv::Rect inclusionRect = bestRect;
    const int expansion = std::max(2, static_cast<int>(std::round(std::min(focusMask.cols, focusMask.rows) * 0.12)));
    inclusionRect.x = std::max(0, inclusionRect.x - expansion);
    inclusionRect.y = std::max(0, inclusionRect.y - expansion);
    inclusionRect.width = std::min(focusMask.cols - inclusionRect.x, inclusionRect.width + (expansion * 2));
    inclusionRect.height = std::min(focusMask.rows - inclusionRect.y, inclusionRect.height + (expansion * 2));

    cv::Mat mergedMask = cv::Mat::zeros(focusMask.size(), CV_8UC1);
    cv::Rect mergedRect;
    bool hasMergedRect = false;
    int mergedArea = 0;

    for (int label = 1; label < labelCount; label++) {
        const int area = stats.at<int>(label, cv::CC_STAT_AREA);
        if (area <= 0) {
            continue;
        }

        cv::Rect rect(
            stats.at<int>(label, cv::CC_STAT_LEFT),
            stats.at<int>(label, cv::CC_STAT_TOP),
            stats.at<int>(label, cv::CC_STAT_WIDTH),
            stats.at<int>(label, cv::CC_STAT_HEIGHT)
        );
        const bool smallNoise = (area / focusArea) < 0.0009;
        const bool insideWorkingZone = (rect & inclusionRect).area() > 0;
        if (smallNoise || !insideWorkingZone) {
            continue;
        }

        cv::Mat labelMask = labels == label;
        labelMask.convertTo(labelMask, CV_8UC1, 255);
        cv::bitwise_or(mergedMask, labelMask, mergedMask);
        mergedArea += area;
        mergedRect = hasMergedRect ? (mergedRect | rect) : rect;
        hasMergedRect = true;
    }

    if (!hasMergedRect || mergedArea <= 0) {
        if (generateDebugImage) {
            analysis.debugImage = rgbaMatFromGray(255 - focusMask);
        }
        return analysis;
    }

    const double componentAreaRatio = mergedArea / focusArea;
    const double inkRatio = static_cast<double>(cv::countNonZero(mergedMask)) / focusArea;
    const bool touchesBorder = mergedRect.x <= 1
        || mergedRect.y <= 1
        || mergedRect.x + mergedRect.width >= focusMask.cols - 1
        || mergedRect.y + mergedRect.height >= focusMask.rows - 1;

    cv::Moments moments = cv::moments(mergedMask, true);
    cv::Point2d centroid(
        moments.m00 > 0 ? moments.m10 / moments.m00 : mergedRect.x + (mergedRect.width * 0.5),
        moments.m00 > 0 ? moments.m01 / moments.m00 : mergedRect.y + (mergedRect.height * 0.5)
    );
    const cv::Point2d focusCenter(focusMask.cols * 0.5, focusMask.rows * 0.5);
    const double dx = centroid.x - focusCenter.x;
    const double dy = centroid.y - focusCenter.y;
    const double centroidDistanceRatio = std::sqrt((dx * dx) + (dy * dy))
        / std::max(1.0, std::sqrt((focusMask.cols * focusMask.cols) + (focusMask.rows * focusMask.rows)) * 0.5);

    const bool isBlankLike = inkRatio < VisionConfig::blankInkRatioThreshold
        || componentAreaRatio < VisionConfig::minComponentAreaRatio
        || (touchesBorder && centroidDistanceRatio > VisionConfig::maxComponentCentroidDistanceRatio);

    if (isBlankLike) {
        analysis.inkRatio = inkRatio;
        analysis.componentAreaRatio = componentAreaRatio;
        analysis.centroidDistanceRatio = centroidDistanceRatio;
        analysis.touchesBorder = touchesBorder;
        if (generateDebugImage) {
            analysis.debugImage = rgbaMatFromGray(255 - mergedMask);
        }
        return analysis;
    }

    cv::Rect paddedRect = mergedRect;
    const int pad = std::max(2, static_cast<int>(std::round(std::min(paddedRect.width, paddedRect.height) * 0.15)));
    paddedRect.x = std::max(0, paddedRect.x - pad);
    paddedRect.y = std::max(0, paddedRect.y - pad);
    paddedRect.width = std::min(focusMask.cols - paddedRect.x, paddedRect.width + (pad * 2));
    paddedRect.height = std::min(focusMask.rows - paddedRect.y, paddedRect.height + (pad * 2));

    cv::Mat croppedMask = mergedMask(paddedRect).clone();
    const int canvasSide = std::max(
        static_cast<int>(std::round(std::max(croppedMask.cols, croppedMask.rows) * (1.0 + VisionConfig::cellPaddingRatio))),
        std::max(croppedMask.cols, croppedMask.rows)
    );
    cv::Mat canvas = cv::Mat::zeros(canvasSide, canvasSide, CV_8UC1);
    const int offsetX = (canvasSide - croppedMask.cols) / 2;
    const int offsetY = (canvasSide - croppedMask.rows) / 2;
    croppedMask.copyTo(canvas(cv::Rect(offsetX, offsetY, croppedMask.cols, croppedMask.rows)));

    cv::Moments canvasMoments = cv::moments(canvas, true);
    if (canvasMoments.m00 > 0) {
        const double cx = canvasMoments.m10 / canvasMoments.m00;
        const double cy = canvasMoments.m01 / canvasMoments.m00;
        const double target = (canvasSide - 1) * 0.5;
        cv::Mat translation = (cv::Mat_<double>(2, 3) << 1, 0, target - cx, 0, 1, target - cy);
        cv::warpAffine(canvas, canvas, translation, canvas.size(), cv::INTER_LINEAR, cv::BORDER_CONSTANT, cv::Scalar(0));
    }

    cv::Mat resizedMask;
    cv::resize(canvas, resizedMask, cv::Size(imageSize, imageSize), 0, 0, cv::INTER_AREA);
    cv::Mat modelInput = 255 - resizedMask;

    analysis.hasMeaningfulInk = true;
    analysis.normalizedDigit = rgbaMatFromGray(modelInput);
    analysis.inkRatio = inkRatio;
    analysis.componentAreaRatio = componentAreaRatio;
    analysis.centroidDistanceRatio = centroidDistanceRatio;
    analysis.touchesBorder = touchesBorder;
    if (generateDebugImage) {
        analysis.debugImage = rgbaMatFromGray(modelInput);
    }
    return analysis;
}

NSDictionary *dictionaryFromBoardCandidate(const BoardCandidate &candidate, bool includeWarpedImage) {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"corners"] = pointArrayFromCorners(candidate.corners);
    dictionary[@"qualityScore"] = @(candidate.totalScore);
    dictionary[@"boardAreaRatio"] = @(candidate.areaRatio);
    dictionary[@"gridConfidence"] = @(candidate.gridScore);
    if (includeWarpedImage) {
        dictionary[@"warpedImage"] = MatToUIImage(candidate.warpedBoard);
    }
    return dictionary;
}

NSDictionary *dictionaryFromCellAnalysis(const CellAnalysis &analysis, bool includeDebugImage) {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[@"hasMeaningfulInk"] = @(analysis.hasMeaningfulInk);
    dictionary[@"inkRatio"] = @(analysis.inkRatio);
    dictionary[@"componentAreaRatio"] = @(analysis.componentAreaRatio);
    dictionary[@"centroidDistanceRatio"] = @(analysis.centroidDistanceRatio);
    dictionary[@"touchesBorder"] = @(analysis.touchesBorder);
    if (analysis.hasMeaningfulInk && !analysis.normalizedDigit.empty()) {
        dictionary[@"normalizedDigitImage"] = MatToUIImage(analysis.normalizedDigit);
    }
    if (includeDebugImage && !analysis.debugImage.empty()) {
        dictionary[@"debugImage"] = MatToUIImage(analysis.debugImage);
    }
    return dictionary;
}

} // namespace

@implementation wrapper

+ (NSDictionary *) detectRectangle: (UIImage *)image {
    @try {
        cv::Mat source;
        UIImageToMat(image, source);
        auto candidate = detectBestBoardCandidate(source);
        if (!candidate.has_value()) {
            return nil;
        }
        return dictionaryFromBoardCandidate(candidate.value(), true);
    }
    @catch (...) {
        return nil;
    }
}

+ (NSDictionary *) warpBoard: (UIImage *)image corners: (NSArray<NSValue *> *)corners {
    @try {
        cv::Mat source;
        UIImageToMat(image, source);
        if (source.empty() || corners.count < 4) {
            return nil;
        }

        std::vector<cv::Point2f> candidateCorners;
        candidateCorners.reserve(4);
        for (NSUInteger index = 0; index < 4; index++) {
            const CGPoint point = corners[index].CGPointValue;
            candidateCorners.push_back(cv::Point2f(point.x, point.y));
        }

        auto candidate = makeBoardCandidateFromCorners(source, candidateCorners);
        if (!candidate.has_value()) {
            return nil;
        }
        return dictionaryFromBoardCandidate(candidate.value(), true);
    }
    @catch (...) {
        return nil;
    }
}

+ (NSMutableArray *) sliceImages: (UIImage *)image imageSize: (int)imageSize cutOffset: (int)cutOffset {
    @try {
        cv::Mat source;
        UIImageToMat(image, source);
        if (source.empty()) {
            return nil;
        }

        const GridBoundaries grid = refineGridBoundaries(source);
        const auto &vertical = grid.vertical;
        const auto &horizontal = grid.horizontal;

        NSMutableArray *cellImages = [[NSMutableArray alloc] initWithCapacity:81];
        cv::Mat mergedImage = cv::Mat::zeros(imageSize * 9, imageSize * 9, CV_8UC4);

        for (int row = 0; row < 9; row++) {
            for (int col = 0; col < 9; col++) {
                const int x0 = std::max(0, vertical[static_cast<size_t>(col)]);
                const int x1 = std::min(source.cols - 1, vertical[static_cast<size_t>(col + 1)]);
                const int y0 = std::max(0, horizontal[static_cast<size_t>(row)]);
                const int y1 = std::min(source.rows - 1, horizontal[static_cast<size_t>(row + 1)]);

                cv::Rect baseRect(
                    x0,
                    y0,
                    std::max(1, x1 - x0),
                    std::max(1, y1 - y0)
                );
                baseRect &= cv::Rect(0, 0, source.cols, source.rows);
                cv::Rect targetRect = symmetricInsetRect(baseRect, cutOffset, source.size());

                cv::Mat sliced = source(targetRect).clone();
                cv::Mat resized;
                cv::resize(sliced, resized, cv::Size(imageSize, imageSize), 0, 0, cv::INTER_AREA);

                [cellImages addObject:MatToUIImage(resized)];

                const int mergedX = col * imageSize;
                const int mergedY = row * imageSize;
                resized.copyTo(mergedImage(cv::Rect(mergedX, mergedY, imageSize, imageSize)));
            }
        }

        NSMutableArray *result = [[NSMutableArray alloc] init];
        [result addObject:cellImages];
        [result addObject:MatToUIImage(mergedImage)];
        return result;
    }
    @catch (...) {
        return nil;
    }
}

+ (NSDictionary *) analyzeCell: (UIImage *)sourceImage imageSize: (int)imageSize {
    @try {
        cv::Mat source;
        UIImageToMat(sourceImage, source);
        if (source.empty()) {
            return nil;
        }

        CellAnalysis analysis = analyzeCellMat(source, imageSize, false);
        return dictionaryFromCellAnalysis(analysis, false);
    }
    @catch (...) {
        return nil;
    }
}

+ (NSMutableArray *) getNumImage: (UIImage *)sourceImage imageSize: (int)imageSize {
    @try {
        cv::Mat source;
        UIImageToMat(sourceImage, source);
        if (source.empty()) {
            return nil;
        }

        CellAnalysis analysis = analyzeCellMat(source, imageSize, true);
        NSMutableArray *result = [[NSMutableArray alloc] init];
        [result addObject:@(analysis.hasMeaningfulInk)];
        UIImage *debugImage = analysis.debugImage.empty()
            ? sourceImage
            : MatToUIImage(analysis.debugImage);
        [result addObject:debugImage];
        return result;
    }
    @catch (...) {
        return nil;
    }
}

+ (NSDictionary *) detectRect: (UIImage *)image {
    @try {
        cv::Mat source;
        UIImageToMat(image, source);
        auto candidate = detectBestBoardCandidate(source);
        if (!candidate.has_value()) {
            return nil;
        }
        return dictionaryFromBoardCandidate(candidate.value(), false);
    }
    @catch (...) {
        return nil;
    }
}

@end
