//
//  wrapper.m
//  Sudoku
//
//  Created by 이주화 on 2022/09/12.
//


#import "wrapper.h"

#ifdef __cplusplus
#undef NO
#undef YES
#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#endif

#import <cmath>

@implementation wrapper


// c++에서 쓰인 포인터(좌표를)를 NSArray로 변환한다.
NSArray *pointToArray(std::vector<cv::Point> vect) {
    NSMutableArray *resultArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < vect.size(); i++)
    {
        NSValue *val = [NSValue valueWithCGPoint:CGPointMake(vect[i].x, vect[i].y)];
        [resultArray addObject:val];
    }
    return resultArray;
}

+ (NSMutableArray *) detectRectangle: (UIImage *)image {
    @try
    {
        // UIImage를 opevCV에서 사용하는 Mat로 변환한다.
        cv::Mat mat;
        UIImageToMat(image, mat);
        
        // grayScale을 입힌다.
        cv::Mat toGray;
        cv::cvtColor(mat, toGray, CV_BGR2GRAY);

        // threshold를 강조한다.
        cv::Mat toThresh;
        cv::adaptiveThreshold(toGray, toThresh, 255, CV_ADAPTIVE_THRESH_MEAN_C, CV_THRESH_BINARY_INV, 31, 31);

        // 테두리를 찾는다.
        std::vector<std::vector<cv::Point>> contours;
        std::vector<cv::Vec4i> hierarchy;
        cv::findContours(toThresh, contours, hierarchy, CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE);
        if (contours.size() < 1)
        {
            //테두리가 없으면...
            return nil;
        }

        // 제일 큰 테두리를 찾는다.
        double maxArea = 0;
        int maxContourIndex = 0;
        for (int i = 0; i < contours.size(); i++)
        {
            double area = cv::contourArea(contours[i]);
            if (area > maxArea)
            {
                maxArea = area;
                maxContourIndex = i;
            }
        }
        std::vector<cv::Point> maxContour = contours[maxContourIndex];

        // 제일 큰 테두리에서 사각형을 찾는다.
        std::vector<int> sumv, diffv;
        for (int i = 0; i < maxContour.size(); i++)
        {
            cv::Point p = maxContour[i];
            sumv.push_back(p.x + p.y);
            diffv.push_back(p.x - p.y);
        }
        // c++의 distance를 이용해 테두리의 각 모서리를 찾는다.
        auto mins = std::distance(std::begin(sumv), std::min_element(std::begin(sumv), std::end(sumv)));
        auto maxs = std::distance(std::begin(sumv), std::max_element(std::begin(sumv), std::end(sumv)));
        auto mind = std::distance(std::begin(diffv), std::min_element(std::begin(diffv), std::end(diffv)));
        auto maxd = std::distance(std::begin(diffv), std::max_element(std::begin(diffv), std::end(diffv)));
        std::vector<cv::Point> maxRect;
        maxRect.push_back(maxContour[mins]); // 왼쪽 위 모서리
        maxRect.push_back(maxContour[mind]); // 오른쪽 위 모서리
        maxRect.push_back(maxContour[maxs]); // 오른쪽 아래 모서리
        maxRect.push_back(maxContour[maxd]); // 왼쪽 아래 모서리
        
        // 구한 모서리를 이용해 각 모서리의 좌표를 구한다.
        cv::Point tl = maxRect[0];
        cv::Point tr = maxRect[1];
        cv::Point br = maxRect[2];
        cv::Point bl = maxRect[3];
        // 좌표간에 거리를 계산한뒤 제곱하고 루트를 씌워 모서리 사이의 거리(변의 길이)를 구한다.
        double widthA = sqrt(pow((br.x - bl.x), 2) + pow((br.y - bl.y), 2));
        double widthB = sqrt(pow((tr.x - tl.x), 2) + pow((tr.y - tl.y), 2));
        double heightA = sqrt(pow((tr.x - br.x), 2) + pow((tr.y - br.y), 2));
        double heightB = sqrt(pow((tl.x - bl.x), 2) + pow((tl.y - bl.y), 2));
        // 평행하는 변 중 긴 변을 구한다.
        double maxWidth = fmax(int(widthA), int(widthB));
        double maxHeight = fmax(int(heightA), int(heightB));

        // 구한 긴 변을 기준으로 짧은 변을 늘린다.
        cv::Point2f dst[4] =
        {
            cv::Point2f(0, 0),
            cv::Point2f(maxWidth, 0),
            cv::Point2f(maxWidth, maxHeight),
            cv::Point2f(0, maxHeight)
        };
        cv::Point2f src[4] = { tl, bl, br, tr };
        cv::Mat M = cv::getPerspectiveTransform(src, dst);
        cv::Mat warpMat;
        cv::warpPerspective(mat, warpMat, M, cv::Size(maxWidth, maxHeight));

        NSMutableArray *result = [[NSMutableArray alloc] init];
        [result addObject:pointToArray(maxRect)];
        [result addObject:MatToUIImage(warpMat)];
        
        return result;
    }
    @catch (...)
    {
        return nil;
    }
}

@end

