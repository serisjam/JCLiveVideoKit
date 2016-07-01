


#import "GPUImageEmptyFilter.h"

@class GPUImageCombinationFilter;
@class GPUImageTwoInputFilter;

@interface GPUImageBeautyFilter : GPUImageFilterGroup
{
    GPUImageBilateralFilter *bilateralFilter;
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;
    GPUImageTwoInputFilter *combinationFilter;
    GPUImageHSBFilter *hsbFilter;
    GPUImageEmptyFilter *gpuemptyImage;
}

@end
