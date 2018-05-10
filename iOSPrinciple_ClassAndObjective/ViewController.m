//
//  ViewController.m
//  iOSPrinciple_ClassAndObjective
//
//  Created by WhatsXie on 2018/5/10.
//  Copyright © 2018年 WhatsXie. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self classPrint];
}

- (void)classPrint {
    NSObject *object1 = [NSObject new];
    NSObject *object2 = [NSObject new];
    
    Class objectClass1 = [object1 class];
    Class objectClass2 = [object2 class];
    Class objectClass3 = [NSObject class];
    // runtime
    Class objectClass4 = object_getClass(object1);
    Class objectClass5 = object_getClass(object2);
    NSLog(@"%p %p %p %p %p", objectClass1, objectClass2, objectClass3, objectClass4, objectClass5);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
