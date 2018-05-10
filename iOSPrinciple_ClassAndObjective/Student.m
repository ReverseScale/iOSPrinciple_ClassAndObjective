//
//  Student.m
//  iOSPrinciple_ClassAndObjective
//
//  Created by WhatsXie on 2018/5/10.
//  Copyright © 2018年 WhatsXie. All rights reserved.
//

#import "Student.h"

@implementation Student
//int main(int argc, const char * argv[]) {
- (void)testStudent {
    @autoreleasepool {
        Student *stu = [[Student alloc] init];
        stu -> _no = 4;
        stu -> _age = 5;
        NSLog(@"%@",stu);
    }
}
@end
