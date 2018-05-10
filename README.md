# iOSPrinciple_ClassAndObjective
Principle Class And Objective

### 关于OC对象的底层实现

寻OC对象的本质，我们平时编写的Objective-C代码，底层实现其实都是C\C++代码。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/93140946.jpg)

OC的对象结构都是通过基础C\C++的结构体实现的。 我们通过创建OC文件及对象，并将OC文件转化为C++文件来探寻OC对象的本质

OC如下代码

```objc
#import <Foundation/Foundation.h>
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSObject *objc = [[NSObject alloc] init];
        NSLog(@"Hello, World!");
    }
    return 0;
}
```

我们通过命令行将OC的mian.m文件转化为c++文件

```
clang -rewrite-objc main.m -o main.cpp // 这种方式没有指定架构例如arm64架构
```

我们可以指定架构模式的命令行，使用xcode工具 xcrun

```
xcrun -sdk iphoneos clang -arch arm64 -rewrite-objc main.m -o main-arm64.cpp // 生成 main-arm64.cpp 
```

main-arm64.cpp 文件中搜索NSObjcet，可以找到 NSObjcet_IMPL（IMPL代表 implementation 实现）

我们看一下NSObject_IMPL内部

```c
struct NSObject_IMPL {
    Class isa;
};
// 查看Class本质
typedef struct objc_class *Class;
// 我们发现Class其实就是一个指针，对象底层实现其实就是这个样子。
```

思考： 一个OC对象在内存中是如何布局的?

NSObjcet的底层实现，点击NSObjcet进入发现NSObject的内部实现

```c
@interface NSObject <NSObject> {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wobjc-interface-ivars"
    Class isa  OBJC_ISA_AVAILABILITY;
    #pragma clang diagnostic pop
}
@end
```

转化为c语言其实就是一个结构体

```c
struct NSObject_IMPL {
    Class isa;
};
```

> 那么这个结构体占多大的内存空间呢，我们发现这个结构体只有一个成员，isa指针，而指针在64位架构中占8个字节。也就是说一个NSObjec对象所占用的内存是8个字节。

为了探寻OC对象在内存中如何体现，我们来看下面一段代码

```c
NSObject *objc = [[NSObject alloc] init];
```

上面一段代码在内存中如何体现的呢？上述一段代码中系统为NSObject对象分配8个字节的内存空间，用来存放一个成员isa指针。那么isa指针这个变量的地址就是结构体的地址，也就是NSObjcet对象的地址。

假设isa的地址为0x100400110，那么上述代码分配存储空间给NSObject对象，然后将存储空间的地址赋值给objc指针。objc存储的就是isa的地址。objc指向内存中NSObject对象地址，即指向内存中的结构体，也就是isa的位置。

#### 自定义类的内部实现

```objc
@interface Student : NSObject{
    @public
    int _no;
    int _age;
}
@end
@implementation Student
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Student *stu = [[Student alloc] init];
        stu -> _no = 4;
        stu -> _age = 5;
        NSLog(@"%@",stu);
    }
    return 0;
}
@end
```

按照上述步骤同样生成c++文件。并查找Student，我们发现Student_IMPL

```objc
struct Student_IMPL {
    struct NSObject_IMPL NSObject_IVARS;
    int _no;
    int _age;
};
```

发现第一个是 NSObject_IMPL的实现。而通过上面的实验我们知道NSObject_IMPL内部其实就是Class isa 那么我们假设 struct NSObject_IMPL NSObject_IVARS;

```c
struct Student_IMPL {
    Class *isa;
    int _no;
    int _age;
};
```

因此此结构体占用多少存储空间，对象就占用多少存储空间。因此结构体占用的存储空间为，isa指针8个字节空间+int类型_no4个字节空间+int类型_age4个字节空间共16个字节空间

```c++
Student *stu = [[Student alloc] init];
stu -> _no = 4;
stu -> _age = 5;
```

那么上述代码实际上在内存中的体现为，创建Student对象首先会分配16个字节，存储3个东西，isa指针8个字节，4个字节的_no ,4个字节的_age

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/41208264.jpg)

sutdent对象的3个变量分别有自己的地址。而stu指向isa指针的地址。因此stu的地址为0x100400110，stu对象在内存中占用16个字节的空间。并且经过赋值，_no里面存储着4 ，_age里面存储着5

验证Student在内存中模样

```objc
struct Student_IMPL {
    Class isa;
    int _no;
    int _age;
};
@interface Student : NSObject {
    @public
    int _no;
    int _age;
}
@end
@implementation Student
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // 强制转化
        struct Student_IMPL *stuImpl = (__bridge struct Student_IMPL *)stu;
        NSLog(@"_no = %d, _age = %d", stuImpl->_no, stuImpl->_age); // 打印出 _no = 4, _age = 5
    }
    return 0;
}
```

上述代码将oc对象强转成Student_IMPL的结构体。也就是说把一个指向oc对象的指针，指向这种结构体。由于我们之前猜想，对象在内存中的布局与结构体在内存中的布局相同，那么如果可以转化成功，说明我们的猜想正确。由此说明stu这个对象指向的内存确实是一个结构体。

实际上想要获取对象占用内存的大小，可以通过更便捷的运行时方法来获取。

```objc
class_getInstanceSize([Student class])
NSLog(@"%zd,%zd", class_getInstanceSize([NSObject class]) ,class_getInstanceSize([Student class]));
// 打印信息 8和16
```

#### 窥探内存结构

实时查看内存数据

方式一：通过打断点。 Debug Workflow -> viewMemory address中输入stu的地址

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/69018395.jpg)

从上图中，我们可以发现读取数据从高位数据开始读，查看前16位字节，每四个字节读出的数据为
16进制 0x0000004(4字节) 0x0000005(4字节)  isa的地址为 00D1081000001119(8字节)

方式二：通过lldb指令xcode自带的调试器

```objc
memory read 0x10074c450
// 简写  x 0x10074c450

// 增加读取条件
// memory read/数量格式字节数  内存地址
// 简写 x/数量格式字节数  内存地址
// 格式 x是16进制，f是浮点，d是10进制
// 字节大小   b：byte 1字节，h：half word 2字节，w：word 4字节，g：giant word 8字节

示例：x/4xw    //   /后面表示如何读取数据 w表示4个字节4个字节读取，x表示以16进制的方式读取数据，4则表示读取4次
```

同时也可以通过lldb修改内存中的值

```c
memory write 0x100400c68 6
将_no的值改为了6
```

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/78128252.jpg)

> 那么一个NSObject对象占用多少内存？ NSObjcet实际上是只有一个名为isa的指针的结构体，因此占用一个指针变量所占用的内存空间大小，如果64bit占用8个字节，如果32bit占用4个字节。

### 更复杂的继承关系

#### 在64bit环境下， 下面代码的输出内容？

```objc
/* Person */
@interface Person: NSObject {
    int _age;
}
@end
@implementation Person
@end
/* Student */
@interface Student: Person {
    int _no;
}
@end
@implementation Student
@end
int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"%zd  %zd",
        class_getInstanceSize([Person class]),
        class_getInstanceSize([Student class])
        );
    }
    return 0;
}
```

我们依据上面的分析与发现，类对象实质上是以结构体的形式存储在内存中，画出真正的内存图例

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/90974378.jpg)

我们发现只要是继承自NSObject的对象，那么底层结构体内一定有一个isa指针。

那么他们所占的内存空间是多少呢？单纯的将指针和成员变量所占的内存相加即可吗？上述代码实际打印的内容是16 16，也就是说，person对象和student对象所占用的内存空间都为16个字节。

其实实际上person对象确实只使用了12个字节。但是因为内存对齐的原因。使person对象也占用16个字节。

我们可以总结内存对齐为两个原则： 
* 原则 1. 前面的地址必须是后面的地址正数倍,不是就补齐。 
* 原则 2. 整个Struct的地址必须是最大字节的整数倍。

通过上述内存对齐的原则我们来看，person对象的第一个地址要存放isa指针需要8个字节，第二个地址要存放_age成员变量需要4个字节，根据原则一，8是4的整数倍，符合原则一，不需要补齐。然后检查原则2，目前person对象共占据12个字节的内存，不是最大字节数8个字节的整数倍，所以需要补齐4个字节，因此person对象就占用16个字节空间。

而对于student对象，我们知道student对象中，包含person对象的结构体实现，和一个int类型的_no成员变量，同样isa指针8个字节，_age成员变量4个字节，_no成员变量4个字节，刚好满足原则1和原则2，所以student对象占据的内存空间也是16个字节。

### OC对象的分类
OC的类信息存放在哪里，对象的isa指针指向哪里?

示例代码
```objc
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
/* Person */ 
@interface Person : NSObject <NSCopying> {
    @public
    int _age;
}
@property (nonatomic, assign) int height;
- (void)personMethod;
+ (void)personClassMethod;
@end
@implementation Person
- (void)personMethod {}
+ (void)personClassMethod {}
@end
/* Student */
@interface Student : Person <NSCoding> {
    @public
    int _no;
}
@property (nonatomic, assign) int score;
- (void)studentMethod;
+ (void)studentClassMethod;
@end
@implementation Student
- (void)studentMethod {}
+ (void)studentClassMethod {}
@end
int main(int argc, const char * argv[]) {
    @autoreleasepool {      
        NSObject *object1 = [[NSObject alloc] init];
        NSObject *object2 = [[NSObject alloc] init];
        Student *stu = [[Student alloc] init];
        [Student load];
        Person *p1 = [[Person alloc] init];
        p1->_age = 10;
        [p1 personMethod];
        [Person personClassMethod];
        Person *p2 = [[Person alloc] init];
        p2->_age = 20;
    }
    return 0;
}
```

#### OC的类信息存放在哪里
OC对象主要可以分为三种

* instance对象（实例对象）
* class对象（类对象）
* meta-class对象（元类对象）

instance对象就是通过类alloc出来的对象，每次调用alloc都会产生新的instance对象
```objc 
NSObjcet *object1 = [[NSObjcet alloc] init];
NSObjcet *object2 = [[NSObjcet alloc] init];
```
object1和object2都是NSObject的instace对象（实例对象），但他们是不同的两个对象，并且分别占据着两块不同的内存。
instance对象在内存中存储的信息包括

* isa指针
* 其他成员变量

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/47918469.jpg)


> 衍生问题：在上图实例对象中根本没有看到方法，那么实例对象的方法的代码放在什么地方呢？那么类的方法的信息，协议的信息，属性的信息都存放在什么地方呢？

*class对象*

我们通过class方法或runtime方法得到一个class对象。class对象也就是类对象

```objc
Class objectClass1 = [object1 class];
Class objectClass2 = [object2 class];
Class objectClass3 = [NSObject class];
// runtime
Class objectClass4 = object_getClass(object1);
Class objectClass5 = object_getClass(object2);
NSLog(@"%p %p %p %p %p", objectClass1, objectClass2, objectClass3, objectClass4, objectClass5);
```

每一个类在内存中有且只有一个class对象

可以通过打印内存地址证明，class对象在内存中存储的信息主要包括

* 1.isa指针
* 2.superclass指针
* 3.类的属性信息（@property），类的成员变量信息（ivar）
* 4.类的对象方法信息（instance method），类的协议信息（protocol）

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/47692243.jpg)

成员变量的值时存储在实例对象中的，因为只有当我们创建实例对象的时候才为成员变赋值。但是成员变量叫什么名字，是什么类型，只需要有一份就可以了。

类方法放在那里？ 元类对象 meta-class

```c
//runtime中传入类对象此时得到的就是元类对象
Class objectMetaClass = object_getClass([NSObject class]);
// 而调用类对象的class方法时得到还是类对象，无论调用多少次都是类对象
Class cls = [[NSObject class] class];
Class objectClass3 = [NSObject class];
class_isMetaClass(objectMetaClass) // 判断该对象是否为元类对象
NSLog(@"%p %p %p", objectMetaClass, objectClass3, cls); // 后面两个地址相同，说明多次调用class得到的还是类对象
```

每个类在内存中有且只有一个meta-class对象。 meta-class对象和class对象的内存结构是一样的，但是用途不一样，在内存中存储的信息主要包括

* 1.isa指针
* 2.superclass指针
* 3.类的类方法的信息（class method）

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/26774430.jpg)

meta-class对象和class对象的内存结构是一样的，所以meta-class中也有类的属性信息，类的对象方法信息等成员变量，但是其中的值可能是空的。

对象的isa指针指向哪里?

1.当对象调用实例方法的时候，我们上面讲到，实例方法信息是存储在class类对象中的，那么要想找到实例方法，就必须找到class类对象，那么此时isa的作用就来了。

```objc
[stu studentMethod];
```

instance的isa指向class，当调用对象方法时，通过instance的isa找到class，最后找到对象方法的实现进行调用。

2.当类对象调用类方法的时候，同上，类方法是存储在meta-class元类对象中的。那么要找到类方法，就需要找到meta-class元类对象，而class类对象的isa指针就指向元类对象

```objc
[Student studentClassMethod];
```

class 的 isa 指向 meta-class 当调用类方法时，通过 class 的 isa 找到 meta-class，最后找到类方法的实现进行调用

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/25988580.jpg)

3.当对象调用其父类对象方法的时候，又是怎么找到父类对象方法的呢？，此时就需要使用到class类对象superclass指针。

```objc
[stu personMethod];
[stu init];
```

当Student的instance对象要调用Person的对象方法时，会先通过isa找到Student的class，然后通过superclass找到Person的class，最后找到对象方法的实现进行调用，同样如果Person发现自己没有响应的对象方法，又会通过Person的superclass指针找到NSObject的class对象，去寻找响应的方法

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/63234730.jpg)

当类对象调用父类的类方法时，就需要先通过isa指针找到meta-class，然后通过superclass去寻找响应的方法

```objc
[Student personClassMethod];
[Student load];
```

当Student的class要调用Person的类方法时，会先通过isa找到Student的meta-class，然后通过superclass找到Person的meta-class，最后找到类方法的实现进行调用

最后又是这张静定的isa指向图，经过上面的分析我们在来看这张图，就显得清晰明了很多。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/9713633.jpg)

对isa、superclass总结
* 1.instance的isa指向class
* 2.class的isa指向meta-class
* 3.meta-class的isa指向基类的meta-class，基类的isa指向自己
* 4.class的superclass指向父类的class，如果没有父类，superclass指针为nil
* 5.meta-class的superclass指向父类的meta-class，基类的meta-class的superclass指向基类的class
* 6.instance调用对象方法的轨迹，isa找到class，方法不存在，就通过superclass找父类
* 7.class调用类方法的轨迹，isa找meta-class，方法不存在，就通过superclass找父类

#### 如何证明isa指针的指向真的如上面所说？

我们通过如下代码证明：
```objc
NSObject *object = [[NSObject alloc] init];
Class objectClass = [NSObject class];
Class objectMetaClass = object_getClass([NSObject class]);
NSLog(@"%p %p %p", object, objectClass, objectMetaClass);
```

打断点并通过控制台打印相应对象的isa指针

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/18249004.jpg)

我们发现object->isa与objectClass的地址不同，这是因为从64bit开始，isa需要进行一次位运算，才能计算出真实地址。而位运算的值我们可以通过下载objc源代码找到。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/66362209.jpg)

我们通过位运算进行验证。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/76279573.jpg)

我们发现，object-isa指针地址0x001dffff96537141经过同0x00007ffffffffff8位运算，得出objectClass的地址0x00007fff96537140

接着我们来验证class对象的isa指针是否同样需要位运算计算出meta-class对象的地址。
当我们以同样的方式打印objectClass->isa指针时，发现无法打印

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/97861552.jpg)

同时也发现左边objectClass对象中并没有isa指针。我们来到Class内部看一下

```c
typedef struct objc_class *Class;
struct objc_class {
    Class _Nonnull isa  OBJC_ISA_AVAILABILITY;
#if !__OBJC2__
    Class _Nullable super_class                              OBJC2_UNAVAILABLE;
    const char * _Nonnull name                               OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list * _Nullable ivars                  OBJC2_UNAVAILABLE;
    struct objc_method_list * _Nullable * _Nullable methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache * _Nonnull cache                       OBJC2_UNAVAILABLE;
    struct objc_protocol_list * _Nullable protocols          OBJC2_UNAVAILABLE;
#endif
} OBJC2_UNAVAILABLE;
/* Use `Class` instead of `struct objc_class *` */
```

相信了解过isa指针的同学对objc_class结构体内的内容很熟悉了，今天这里不深入研究，我们只看第一个对象是一个isa指针，为了拿到isa指针的地址，我们自己创建一个同样的结构体并通过强制转化拿到isa指针。

```c
struct xx_cc_objc_class{
Class isa;
};
Class objectClass = [NSObject class];
struct xx_cc_objc_class *objectClass2 = (__bridge struct xx_cc_objc_class *)(objectClass);
```

此时我们重新验证一下

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/67609570.jpg)

确实，objectClass2的isa指针经过位运算之后的地址是meta-class的地址。

### 关于OC Class 的底层实现

#### Class的本质

我们知道不管是类对象还是元类对象，类型都是Class，class和mete-class的底层都是objc_class结构体的指针，内存中就是结构体，本章来探寻Class的本质。

```objc
Class objectClass = [NSObject class];        
Class objectMetaClass = object_getClass([NSObject class]);
```

点击Class来到内部，我们可以发现

```objc
typedef struct objc_class *Class;
```

Class对象其实是一个指向objc_class结构体的指针。因此我们可以说类对象或元类对象在内存中其实就是objc_class结构体。

我们来到objc_class内部，可以看到这段在底层原理中经常出现的代码。

```c
struct objc_class {
    Class _Nonnull isa  OBJC_ISA_AVAILABILITY;
#if !__OBJC2__
    Class _Nullable super_class                              OBJC2_UNAVAILABLE;
    const char * _Nonnull name                               OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list * _Nullable ivars                  OBJC2_UNAVAILABLE;
    struct objc_method_list * _Nullable * _Nullable methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache * _Nonnull cache                       OBJC2_UNAVAILABLE;
    struct objc_protocol_list * _Nullable protocols          OBJC2_UNAVAILABLE;
#endif
} OBJC2_UNAVAILABLE;
/* Use `Class` instead of `struct objc_class *` */
```

这部分代码相信在文章中很常见，但是OBJC2_UNAVAILABLE;说明这些代码已经不在使用了。那么目前objc_class的结构是什么样的呢？我们通过objc源码中去查找objc_class结构体的内容

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/70121792.jpg)

我们发现这个结构体继承 objc_object 并且结构体内有一些函数，因为这是c++结构体，在c上做了扩展，因此结构体中可以包含函数。我们来到objc_object内，截取部分代码

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/26481697.jpg)

我们发现objc_object中有一个isa指针，那么objc_class继承objc_object，也就同样拥有一个isa指针

那么我们之前了解到的，类中存储的类的成员变量信息，实例方法，属性名等这些信息在哪里呢。我们来到class_rw_t中，截取部分代码，我们发现class_rw_t中存储着方法列表，属性列表，协议列表等内容。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/39793185.jpg)

而class_rw_t是通过bits调用data方法得来的，我们来到data方法内部实现。我们可以看到，data函数内部仅仅对bits进行&FAST_DATA_MASK操作

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/94897176.jpg)

而成员变量信息则是存储在class_ro_t内部中的，我们来到class_ro_t内查看

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/95030801.jpg)

最后总结通过一张图进行总结

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/76965890.jpg)

我们可以自定义一个结构体，如果我们自己写的结构和objc_class真实结构是一样的，那么当我们强制转化的时候，就会一一对应的赋值。此时我们就可以拿到结构体内部的信息。

下列代码是我们仿照objc_class结构体，提取其中需要使用到的信息，自定义的一个结构体。

```c
#import <Foundation/Foundation.h>
#ifndef XXClassInfo_h
#define XXClassInfo_h
# if __arm64__
#   define ISA_MASK        0x0000000ffffffff8ULL
# elif __x86_64__
#   define ISA_MASK        0x00007ffffffffff8ULL
# endif
#if __LP64__
    typedef uint32_t mask_t;
#else
    typedef uint16_t mask_t;
#endif
    typedef uintptr_t cache_key_t;
struct bucket_t {
    cache_key_t _key;
    IMP _imp;
};
struct cache_t {
    bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
};
struct entsize_list_tt {
    uint32_t entsizeAndFlags;
    uint32_t count;
};
struct method_t {
    SEL name;
    const char *types;
    IMP imp;
};
struct method_list_t : entsize_list_tt {
    method_t first;
};
struct ivar_t {
    int32_t *offset;
    const char *name;
    const char *type;
    uint32_t alignment_raw;
    uint32_t size;
};
struct ivar_list_t : entsize_list_tt {
    ivar_t first;
};
struct property_t {
    const char *name;
    const char *attributes;
};
struct property_list_t : entsize_list_tt {
    property_t first;
};
struct chained_property_list {
    chained_property_list *next;
    uint32_t count;
    property_t list[0];
};
typedef uintptr_t protocol_ref_t;
    struct protocol_list_t {
    uintptr_t count;
    protocol_ref_t list[0];
};
struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instanceSize;  // instance对象占用的内存空间
#ifdef __LP64__
    uint32_t reserved;
#endif
    const uint8_t * ivarLayout;
    const char * name;  // 类名
    method_list_t * baseMethodList;
    protocol_list_t * baseProtocols;
    const ivar_list_t * ivars;  // 成员变量列表
    const uint8_t * weakIvarLayout;
    property_list_t *baseProperties;
};
struct class_rw_t {
    uint32_t flags;
    uint32_t version;
    const class_ro_t *ro;
    method_list_t * methods;    // 方法列表
    property_list_t *properties;    // 属性列表
    const protocol_list_t * protocols;  // 协议列表
    Class firstSubclass;
    Class nextSiblingClass;
    char *demangledName;
};
#define FAST_DATA_MASK          0x00007ffffffffff8UL
struct class_data_bits_t {
    uintptr_t bits;
    public:
    class_rw_t* data() { // 提供data()方法进行 & FAST_DATA_MASK 操作
        return (class_rw_t *)(bits & FAST_DATA_MASK);
    }
};
/* OC对象 */
struct xx_objc_object {
    void *isa;
};
/* 类对象 */
struct xx_objc_class : xx_objc_object {
    Class superclass;
    cache_t cache;
    class_data_bits_t bits;
    public:
    class_rw_t* data() {
        return bits.data();
    }
    xx_objc_class* metaClass() { // 提供metaClass函数，获取元类对象
    // 上一篇我们讲解过，isa指针需要经过一次 & ISA_MASK操作之后才得到真正的地址
        return (xx_objc_class *)((long long)isa & ISA_MASK);
    }
};
#endif /* XXClassInfo_h */
```

接下来我们将自己定义的类强制转化为我们自定义的精简的class结构体类型。

```c
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "XXClassInfo.h"
/* Person */
@interface Person : NSObject <NSCopying> {
    @public
    int _age;
}
@property (nonatomic, assign) int height;
- (void)personMethod;
+ (void)personClassMethod;
@end
@implementation Person
- (void)personMethod {}
+ (void)personClassMethod {}
@end
/* Student */
@interface Student : Person <NSCoding> {
    @public
    int _no;
}
@property (nonatomic, assign) int score;
- (void)studentMethod;
+ (void)studentClassMethod;
@end
@implementation Student
- (void)studentMethod {}
+ (void)studentClassMethod {}
@end
int main(int argc, const char * argv[]) {
    @autoreleasepool {
    NSObject *object = [[NSObject alloc] init];
    Person *person = [[Person alloc] init];
    Student *student = [[Student alloc] init];
    xx_objc_class *objectClass = (__bridge xx_objc_class *)[object class];
    xx_objc_class *personClass = (__bridge xx_objc_class *)[person class];
    xx_objc_class *studentClass = (__bridge xx_objc_class *)[student class];
    xx_objc_class *objectMetaClass = objectClass->metaClass();
    xx_objc_class *personMetaClass = personClass->metaClass();
    xx_objc_class *studentMetaClass = studentClass->metaClass();
    class_rw_t *objectClassData = objectClass->data();
    class_rw_t *personClassData = personClass->data();
    class_rw_t *studentClassData = studentClass->data();
    class_rw_t *objectMetaClassData = objectMetaClass->data();
    class_rw_t *personMetaClassData = personMetaClass->data();
    class_rw_t *studentMetaClassData = studentMetaClass->data();
    // 0x00007ffffffffff8
    NSLog(@"%p %p %p %p %p %p",  objectClassData, personClassData, studentClassData,
    objectMetaClassData, personMetaClassData, studentMetaClassData);
    return 0;
}
```

通过打断点，我们可以看到class内部信息。

至此，我们再次拿出那张经典的图，挨个分析图中isa指针和superclass指针的指向

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/80816071.jpg)

#### instance对象
首先我们来看instance对象，我们通过上一篇文章知道，instance对象中存储着isa指针和其他成员变量，并且instance对象的isa指针是指向其类对象地址的。我们首先分析上述代码中我们创建的object，person，student三个instance对象与其相对应的类对象objectClass，personClass，studentClass。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/65276603.jpg)

从上图中我们可以发现instance对象中确实存储了isa指针和其成员变量，同时将instance对象的isa指针经过&运算之后计算出的地址确实是其相应类对象的内存地址。由此我们证明isa，superclass指向图中的1，2，3号线。

#### class对象

接着我们来看class对象，同样通过上一篇文章，我们明确class对象中存储着isa指针，superclass指针，以及类的属性信息，类的成员变量信息，类的对象方法，和类的协议信息，而通过上面对object源码的分析，我们知道这些信息存储在class对象的class_rw_t中，我们通过强制转化来窥探其中的内容。如下图

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/55956695.jpg)

上图中我们通过模拟对person类对象调用.data函数，即对bits进行&FAST_DATA_MASK(0x00007ffffffffff8UL)运算，并转化为class_rw_t。即上图中的personClassData。其中我们发现成员变量信息，对象方法，属性等信息只显示first第一个，如果想要拿到更多的需要通过代码将指针后移获取。

而上图中的instaceSize = 16也同person对象中isa指针8个字节+_age4个字节+_height4个字节相对应起来。这里不在展开对objectClassData及studentClassData进行分析，基本内容同personClassData相同。

那么类对象中的isa指针和superclass指针的指向是否如那张经典的图示呢？我们来验证一下。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/44194746.jpg)

通过上图中的内存地址的分析，由此我们证明isa，superclass指向图中，isa指针的4，5，6号线，以及superclass指针的10，11，12号线。

#### meta-class对象

最后我们来看meta-class元类对象，上文提到meta-class中存储着isa指针，superclass指针，以及类的类方法信息。同时我们知道meta-class元类对象与class类对象，具有相同的结构，只不过存储的信息不同，并且元类对象的isa指针指向基类的元类对象，基类的元类对象的isa指针指向自己。元类对象的superclass指针指向其父类的元类对象，基类的元类对象的superclass指针指向其类对象。

与class对象相同，我们同样通过模拟对person元类对象调用.data函数，即对bits进行&FAST_DATA_MASK(0x00007ffffffffff8UL)运算，并转化为class_rw_t。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/76930502.jpg)

首先我们可以看到结构同personClassData相同，并且成员变量及属性列表等信息为空，而methods中存储着类方法personClassMethod。

接着来验证isa及superclass指针的指向是否同上图序号标注一样。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/60621174.jpg)

上图中通过地址证明meta-class的isa指向基类的meta-class，基类的isa指针也指向自己。

![](http://og1yl0w9z.bkt.clouddn.com/18-5-10/40027312.jpg)

上图中通过地址证明meta-class的superclass指向父类的meta-class，基类的meta-class的superclass指向基类的class类。

以上原理解析文章来源：https://juejin.im/post/5ac81c75518825556534c0af、https://juejin.im/post/5ad210636fb9a028da7cf90c
