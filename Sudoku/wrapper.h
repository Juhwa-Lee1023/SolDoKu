//
//  wrapper.h
//  Sudoku
//
//  Created by 이주화 on 2022/09/12.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface wrapper : NSObject

+ (NSMutableArray *) detectRectangle: (UIImage *)image;

@end
