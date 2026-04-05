//
//  wrapper.h
//  Sudoku
//
//  Created by 이주화 on 2022/09/12.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface wrapper : NSObject

+ (NSDictionary *) detectRectangle: (UIImage *)image;
+ (NSDictionary *) warpBoard: (UIImage *)image corners: (NSArray<NSValue *> *)corners;
+ (NSMutableArray *) sliceImages: (UIImage *)image imageSize: (int)imageSize cutOffset: (int)cutOffset;
+ (NSMutableArray *) getNumImage: (UIImage *)sourceImage imageSize: (int)imageSize;
+ (NSDictionary *) analyzeCell: (UIImage *)sourceImage imageSize: (int)imageSize;
+ (NSDictionary *) detectRect: (UIImage *)image;


@end
