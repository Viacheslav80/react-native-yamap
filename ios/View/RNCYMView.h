#ifndef RNCYMView_h
#define RNCYMView_h
#import <React/RCTComponent.h>

#import <MapKit/MapKit.h>
#import <RNYMView.h>
@import YandexMapsMobile;

@class RCTBridge;

@interface RNCYMView: RNYMView<YMKClusterListener, RCTComponent, YMKClusterTapListener>

- (void)setClusterColor:(UIColor*_Nullable)color;
- (void)setClusteredMarkers:(NSArray<YMKRequestPoint*>*_Nonnull)points;
- (void)setInitialRegion:(NSDictionary *_Nullable)initialRegion;
- (void)insertReactSubview:(UIView *_Nullable)subview atIndex:(NSInteger)atIndex;
- (void)removeReactSubview:(UIView *_Nullable)subview;
- (void)fitAllMarkers;
- (void)fitMarkers:(NSArray<YMKPoint *> *)points;

@end

#endif /* RNYMView_h */
