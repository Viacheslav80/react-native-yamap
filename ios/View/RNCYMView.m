#import <React/RCTComponent.h>
#import <React/UIView+React.h>

#import <MapKit/MapKit.h>
#import "../Converter/RCTConvert+Yamap.m"
@import YandexMapsMobile;

#ifndef MAX
#import <NSObjCRuntime.h>
#endif

#import "RNCYMView.h"
#import <YamapMarkerView.h>

#import "YamapPolygonView.h"
#import "YamapPolylineView.h"
#import "YamapCircleView.h"

#define ANDROID_COLOR(c) [UIColor colorWithRed:((c>>16)&0xFF)/255.0 green:((c>>8)&0xFF)/255.0 blue:((c)&0xFF)/255.0  alpha:((c>>24)&0xFF)/255.0]

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@implementation RNCYMView {
    YMKMasstransitSession *masstransitSession;
    YMKMasstransitSession *walkSession;
    YMKMasstransitRouter *masstransitRouter;
    YMKDrivingRouter* drivingRouter;
    YMKDrivingSession* drivingSession;
    YMKPedestrianRouter *pedestrianRouter;
    YMKTransitOptions *transitOptions;
    YMKMasstransitSessionRouteHandler routeHandler;
    NSMutableArray<UIView*> *_reactSubviews;
    NSMutableArray *routes;
    NSMutableArray *currentRouteInfo;
    NSMutableArray<YMKRequestPoint *>* lastKnownRoutePoints;
    YMKUserLocationView* userLocationView;
    NSMutableDictionary *vehicleColors;
    UIImage* userLocationImage;
    NSArray *acceptVehicleTypes;
    YMKUserLocationLayer *userLayer;
    UIColor* userLocationAccuracyFillColor;
    UIColor* userLocationAccuracyStrokeColor;
    float userLocationAccuracyStrokeWidth;
    YMKClusterizedPlacemarkCollection *clusterCollection;
    UIColor* clusterColor;
    NSMutableArray<YMKPlacemarkMapObject *>* placemarks;
    BOOL userClusters;
    Boolean initializedRegion;
}

- (instancetype)init {
    self = [super init];
    _reactSubviews = [[NSMutableArray alloc] init];
    placemarks = [[NSMutableArray alloc] init];
    clusterColor=nil;
    userClusters=NO;
    clusterCollection = [self.mapWindow.map.mapObjects addClusterizedPlacemarkCollectionWithClusterListener:self];
    initializedRegion = NO;
    return self;
}

- (void)setClusteredMarkers:(NSArray*) markers {
    [placemarks removeAllObjects];
    [clusterCollection clear];
    NSMutableArray<YMKPoint*> *newMarkers = [NSMutableArray new];
    for (NSDictionary *mark in markers) {
        [newMarkers addObject:[YMKPoint pointWithLatitude:[[mark objectForKey:@"lat"] doubleValue] longitude:[[mark objectForKey:@"lon"] doubleValue]]];
    }
    NSArray<YMKPlacemarkMapObject *>* newPlacemarks = [clusterCollection addPlacemarksWithPoints:newMarkers image:[self clusterImage:[NSNumber numberWithFloat:[newMarkers count]]] style:[YMKIconStyle new]];
    [placemarks addObjectsFromArray:newPlacemarks];
    for (int i=0; i<[placemarks count]; i++) {
        if (i<[_reactSubviews count]) {
            UIView *subview = [_reactSubviews objectAtIndex:i];
            if ([subview isKindOfClass:[YamapMarkerView class]]) {
                YamapMarkerView* marker = (YamapMarkerView*) subview;
                [marker setClusterMapObject:[placemarks objectAtIndex:i]];
            }
        }
    }
    [clusterCollection clusterPlacemarksWithClusterRadius:50 minZoom:12];
}

- (void)setClusterColor: (UIColor*) color {
    clusterColor = color;
}

- (void)onObjectRemovedWithView:(nonnull YMKUserLocationView *) view {
}

- (void)onMapTapWithMap:(nonnull YMKMap *) map
                  point:(nonnull YMKPoint *) point {
    if (self.onMapPress) {
        NSDictionary* data = @{
            @"lat": [NSNumber numberWithDouble:point.latitude],
            @"lon": [NSNumber numberWithDouble:point.longitude],
        };
        self.onMapPress(data);
    }
}

- (void)onMapLongTapWithMap:(nonnull YMKMap *) map
                      point:(nonnull YMKPoint *) point {
    if (self.onMapLongPress) {
        NSDictionary* data = @{
            @"lat": [NSNumber numberWithDouble:point.latitude],
            @"lon": [NSNumber numberWithDouble:point.longitude],
        };
        self.onMapLongPress(data);
    }
}

// utils
+ (UIColor*)colorFromHexString:(NSString*) hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1];
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

+ (NSString*)hexStringFromColor:(UIColor *) color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
}

// children
- (void)addSubview:(UIView *) view {
    [super addSubview:view];
}

- (void)insertReactSubview:(UIView<RCTComponent>*) subview atIndex:(NSInteger) atIndex {
    NSLog(@"=== INSERT SUBVIEW ===");
    NSLog(@"Subview class: %@", [subview class]);
    NSLog(@"AtIndex: %ld", (long)atIndex);

    if ([subview isKindOfClass:[YamapMarkerView class]]) {
     NSLog(@"👉 Found YamapMarkerView - ADDING TO MAP");
        YamapMarkerView* marker = (YamapMarkerView*) subview;
        if (atIndex<[placemarks count]) {
            [marker setClusterMapObject:[placemarks objectAtIndex:atIndex]];
        }
    }
    
    // ДОБАВЛЯЕМ ОБРАБОТКУ ПРИМИТИВОВ
    else if ([subview isKindOfClass:[YamapPolygonView class]]) {
        NSLog(@"👉 Found YamapPolygonView - ADDING TO MAP");
        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapPolygonView *polygon = (YamapPolygonView *) subview;
        YMKPolygonMapObject *obj = [objects addPolygonWithPolygon:[polygon getPolygon]];
        [polygon setMapObject:obj];
    } else if ([subview isKindOfClass:[YamapPolylineView class]]) {
        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapPolylineView *polyline = (YamapPolylineView*) subview;
        YMKPolylineMapObject *obj = [objects addPolylineWithPolyline:[polyline getPolyline]];
        [polyline setMapObject:obj];
    } else if ([subview isKindOfClass:[YamapCircleView class]]) {
        NSLog(@"👉 Found YamapCircleView - ADDING TO MAP");
        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapCircleView *circle = (YamapCircleView*) subview;
        YMKCircleMapObject *obj = [objects addCircleWithCircle:[circle getCircle]];
        [circle setMapObject:obj];
    }
    // Обработка вложенных children
    else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
            [self insertReactSubview:(UIView *)childSubviews[i] atIndex:atIndex];
        }
    }

    [_reactSubviews insertObject:subview atIndex:atIndex];
    [super insertMarkerReactSubview:subview atIndex:atIndex];

    NSLog(@"Total reactSubviews count: %lu", (unsigned long)[_reactSubviews count]);
}

- (void)removeReactSubview:(UIView<RCTComponent>*) subview {


    if ([subview isKindOfClass:[YamapMarkerView class]]) {
        YamapMarkerView* marker = (YamapMarkerView*) subview;
        [clusterCollection removeWithMapObject:[marker getMapObject]];
    }
    // ДОБАВЛЯЕМ ОБРАБОТКУ ПРИМИТИВОВ
    else if ([subview isKindOfClass:[YamapPolygonView class]]) {
        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapPolygonView *polygon = (YamapPolygonView *) subview;
        [objects removeWithMapObject:[polygon getMapObject]];
    } else if ([subview isKindOfClass:[YamapPolylineView class]]) {
        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapPolylineView *polyline = (YamapPolylineView *) subview;
        [objects removeWithMapObject:[polyline getMapObject]];
    } else if ([subview isKindOfClass:[YamapCircleView class]]) {

        YMKMapObjectCollection *objects = self.mapWindow.map.mapObjects;
        YamapCircleView *circle = (YamapCircleView *) subview;
        [objects removeWithMapObject:[circle getMapObject]];
    }

    // Обработка вложенных children
    else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
            [self removeReactSubview:(UIView *)childSubviews[i]];
        }
    }

    [_reactSubviews removeObject:subview];
    [super removeMarkerReactSubview:subview];
}

/* -(UIImage*)clusterImage:(NSNumber*) clusterSize {
    float FONT_SIZE = 45;
    float MARGIN_SIZE = 9;
    float STROKE_SIZE = 9;
    NSString *text = [clusterSize stringValue];
    UIFont *font = [UIFont systemFontOfSize:FONT_SIZE];
    CGSize size = [text sizeWithFont:font];
    float textRadius = sqrt(size.height * size.height + size.width * size.width) / 2;
    float internalRadius = textRadius + MARGIN_SIZE;
    float externalRadius = internalRadius + STROKE_SIZE;
    UIImage *someImageView = [UIImage alloc];
    // This function returns a newImage, based on image, that has been:
    // - scaled to fit in (CGRect) rect
    // - and cropped within a circle of radius: rectWidth/2

    //Create the bitmap graphics context
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(externalRadius*2, externalRadius*2), NO, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [clusterColor CGColor]);
    CGContextFillEllipseInRect(context, CGRectMake(0, 0, externalRadius*2, externalRadius*2));
    CGContextSetFillColorWithColor(context, [UIColor.whiteColor CGColor]);
    CGContextFillEllipseInRect(context, CGRectMake(STROKE_SIZE, STROKE_SIZE, internalRadius*2, internalRadius*2));
    [text drawInRect:CGRectMake(externalRadius - size.width/2, externalRadius - size.height/2, size.width, size.height) withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor }];
       UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
       UIGraphicsEndImageContext();

       return newImage;
} */

-(UIImage*)clusterImage:(NSNumber*) clusterSize {
    NSString *text = [clusterSize stringValue];

    // Создаем базовую иконку улья
    UIImage *hiveIcon = [self createHiveBaseIcon];

    // Рисуем число поверх иконки
    return [self drawTextOnHiveIcon:hiveIcon text:text];
}

-(UIImage*)createHiveBaseIcon {
    // Размеры как в SVG
    float width = 71.0f;
    float height = 78.0f;
    float scale = 1.4f;

    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width * scale, height * scale), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, scale, scale);

    // Основной белый шестиугольник
    UIBezierPath *outerHexagon = [UIBezierPath bezierPath];
    [outerHexagon moveToPoint:CGPointMake(39.5673, 1.06982)];
    [outerHexagon addLineToPoint:CGPointMake(31.4327, 1.0696)];
    [outerHexagon addLineToPoint:CGPointMake(4.06851, 16.5748)];
    [outerHexagon addLineToPoint:CGPointMake(0, 23.4905)];
    [outerHexagon addLineToPoint:CGPointMake(0, 54.5072)];
    [outerHexagon addLineToPoint:CGPointMake(4.0673, 61.4225)];
    [outerHexagon addLineToPoint:CGPointMake(31.4327, 76.9302)];
    [outerHexagon addLineToPoint:CGPointMake(39.5673, 76.9302)];
    [outerHexagon addLineToPoint:CGPointMake(66.9327, 61.4225)];
    [outerHexagon addLineToPoint:CGPointMake(71, 54.5072)];
    [outerHexagon addLineToPoint:CGPointMake(71, 23.4926)];
    [outerHexagon addLineToPoint:CGPointMake(66.9327, 16.5772)];
    [outerHexagon closePath];

    [[UIColor whiteColor] setFill];
    [outerHexagon fill];

    // Внутренний шестиугольник с обводкой
    UIBezierPath *innerHexagon = [UIBezierPath bezierPath];
    [innerHexagon moveToPoint:CGPointMake(32.8515, 12.5576)];
    [innerHexagon addLineToPoint:CGPointMake(37.3164, 12.5576)];
    [innerHexagon addLineToPoint:CGPointMake(57.3056, 23.8604)];
    [innerHexagon addLineToPoint:CGPointMake(59.5156, 27.5957)];
    [innerHexagon addLineToPoint:CGPointMake(59.5156, 50.2012)];
    [innerHexagon addLineToPoint:CGPointMake(57.3056, 53.9355)];
    [innerHexagon addLineToPoint:CGPointMake(37.3164, 65.2383)];
    [innerHexagon addLineToPoint:CGPointMake(33.1133, 65.376)];
    [innerHexagon addLineToPoint:CGPointMake(32.8515, 65.2383)];
    [innerHexagon addLineToPoint:CGPointMake(12.8613, 53.9355)];
    [innerHexagon addLineToPoint:CGPointMake(10.6523, 50.2012)];
    [innerHexagon addLineToPoint:CGPointMake(10.6523, 27.5938)];
    [innerHexagon addLineToPoint:CGPointMake(12.8623, 23.8594)];
    [innerHexagon closePath];

    UIColor *orangeColor = [UIColor colorWithRed:255.0/255.0 green:79.0/255.0 blue:18.0/255.0 alpha:1.0];
    [orangeColor setStroke];
    innerHexagon.lineWidth = 3.0;
    [innerHexagon stroke];

    UIImage *baseIcon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return baseIcon;
}

-(UIImage*)drawTextOnHiveIcon:(UIImage*)hiveIcon text:(NSString*)text {
    UIFont *font;
    //font = [UIFont boldSystemFontOfSize:22];
    font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    UIColor *orangeColor = [UIColor colorWithRed:255.0/255.0 green:79.0/255.0 blue:18.0/255.0 alpha:1.0];

    UIGraphicsBeginImageContextWithOptions(hiveIcon.size, NO, hiveIcon.scale);
    [hiveIcon drawInRect:CGRectMake(0, 0, hiveIcon.size.width, hiveIcon.size.height)];

    NSDictionary *textAttributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: orangeColor,
        NSStrokeColorAttributeName: [UIColor whiteColor],
        NSStrokeWidthAttributeName: @-2.0
    };

    CGSize textSize = [text sizeWithAttributes:textAttributes];
    CGPoint textPoint = CGPointMake(
        (hiveIcon.size.width - textSize.width) / 2,
        (hiveIcon.size.height - textSize.height) / 2
    );

    [text drawAtPoint:textPoint withAttributes:textAttributes];

    UIImage *resultImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return resultImage;
}

- (void)onClusterAddedWithCluster:(nonnull YMKCluster *)cluster {
    NSNumber *myNum = @([cluster size]);
    [[cluster appearance] setIconWithImage:[self clusterImage:myNum]];
    [cluster addClusterTapListenerWithClusterTapListener:self];
}

- (BOOL)onClusterTapWithCluster:(nonnull YMKCluster *)cluster {
    NSMutableArray<YMKPoint*>* lastKnownMarkers = [[NSMutableArray alloc] init];
    for (YMKPlacemarkMapObject *placemark in [cluster placemarks]) {
        [lastKnownMarkers addObject:[placemark geometry]];
    }
    [self fitMarkers:lastKnownMarkers];
    return YES;
}

- (void)setInitialRegion:(NSDictionary *)initialParams {
    if (initializedRegion) return;
    if ([initialParams valueForKey:@"lat"] == nil || [initialParams valueForKey:@"lon"] == nil) return;

    float initialZoom = 10.f;
    float initialAzimuth = 0.f;
    float initialTilt = 0.f;

    if ([initialParams valueForKey:@"zoom"] != nil) initialZoom = [initialParams[@"zoom"] floatValue];

    if ([initialParams valueForKey:@"azimuth"] != nil) initialTilt = [initialParams[@"azimuth"] floatValue];

    if ([initialParams valueForKey:@"tilt"] != nil) initialTilt = [initialParams[@"tilt"] floatValue];

    YMKPoint *initialRegionCenter = [RCTConvert YMKPoint:@{@"lat" : [initialParams valueForKey:@"lat"], @"lon" : [initialParams valueForKey:@"lon"]}];
    YMKCameraPosition *initialRegioPosition = [YMKCameraPosition cameraPositionWithTarget:initialRegionCenter zoom:initialZoom azimuth:initialAzimuth tilt:initialTilt];
    [self.mapWindow.map moveWithCameraPosition:initialRegioPosition];
    initializedRegion = YES;
}


@synthesize reactTag;

@end
