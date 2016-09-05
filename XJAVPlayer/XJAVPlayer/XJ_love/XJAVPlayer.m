//
//  XJAVPlayer.m
//  XJAVPlayer
//
//  Created by xj_love on 16/9/1.
//  Copyright © 2016年 Xander. All rights reserved.
//

#import "XJAVPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "UIView+SCYCategory.h"
#import "UIDevice+XJDevice.h"

#define WS(weakSelf) __unsafe_unretained __typeof(&*self)weakSelf = self;

@interface XJAVPlayer (){
    UITapGestureRecognizer *xjTapGesture;//单击收起/弹出菜单
    BOOL isHiden;//底部菜单是否收起
    BOOL isPlay;//是否播放
    BOOL isFull;//是否全屏
    BOOL isFirst;//是否第一次加载
    BOOL isAutoOrient;//自动旋转（不是用放大按钮）
    CGRect xjPlayerFrame;//自定义的视屏大小
}

@property (nonatomic, strong) UIView *bottomMenuView;//底部菜单
@property (nonatomic, strong) UIButton *playOrPauseBtn;//开始/暂停按钮
@property (nonatomic, strong) UIButton *nextPlayerBtn;//下一个视屏
@property (nonatomic, strong) UIProgressView *loadProgressView;//缓冲进度条
@property (nonatomic, strong) UISlider *playSlider;//播放滑动条
@property (nonatomic, strong) UIButton *fullOrSmallBtn;//放大/缩小按钮
@property (nonatomic, strong) UILabel *timeLabel;//时间标签
@property (nonatomic, strong) UIActivityIndicatorView *loadingView;

@property (nonatomic, strong) AVPlayer *xjPlayer;
@property (nonatomic, strong) AVPlayerItem *xjPlayerItem;

@property (nonatomic, strong) id playbackTimeObserver;//界面更新时间ID
@property (nonatomic, strong) NSString *avTotalTime;//视屏时间总长；

@end

@implementation XJAVPlayer

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayer*)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVPlayer *)p {
    [(AVPlayerLayer *)[self layer] setPlayer:p];
}

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor blackColor];
        [self setUserInteractionEnabled:NO];
        xjPlayerFrame = frame;
    }
    return self;
}

- (void)xjPlayerInit{
    //限制锁屏
    [UIApplication sharedApplication].idleTimerDisabled=YES;
    self.xjPlayerItem = [[AVPlayerItem alloc] initWithURL:[NSURL URLWithString:self.xjPlayerUrl]];
    [self.xjPlayerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];//监听status属性变化
    [self.xjPlayerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];//见天loadedTimeRanges属性变化
    
    self.xjPlayer = [AVPlayer playerWithPlayerItem:self.xjPlayerItem];
    [self setPlayer:self.xjPlayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xjPlayerEndPlay:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.xjPlayerItem];//注册监听，视屏播放完成
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientChange:) name:UIDeviceOrientationDidChangeNotification object:nil];//注册监听，屏幕方向改变
}

#pragma mark - 添加控件
- (void)addToolView{
    
    xjTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showOrHidenMenuView)];
    xjTapGesture.cancelsTouchesInView = NO;
    [self addGestureRecognizer:xjTapGesture];
    
    [self addSubview:self.bottomMenuView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
    tap.cancelsTouchesInView = NO;
    [self.bottomMenuView addGestureRecognizer:tap];//防止bottomMenuView也响应了self这个view的单击手势
    [self.bottomMenuView addSubview:self.playOrPauseBtn];
    [self.bottomMenuView addSubview:self.nextPlayerBtn];
    [self.bottomMenuView addSubview:self.fullOrSmallBtn];
    [self.bottomMenuView addSubview:self.timeLabel];
    [self.bottomMenuView addSubview:self.loadProgressView];
    [self.bottomMenuView addSubview:self.playSlider];
    [self addSubview:self.loadingView];
}

#pragma mark - 单击隐藏或者展开底部菜单
- (void)showOrHidenMenuView{
    NSLog(@"haha");
    if (isHiden) {
        [UIView animateWithDuration:0.3 animations:^{
            self.bottomMenuView.hidden  = NO;
            isHiden = NO;
        }];
    }else{
        [UIView animateWithDuration:0.3 animations:^{
            self.bottomMenuView.hidden  = YES;
            isHiden = YES;
        }];
    }
}
#pragma mark - 调节音量
- (void)changeXJPlayerVolume:(id)sender{
    
}

#pragma mark - 控件事件
//开始/暂停视频播放
- (void)playOrPauseAction{
    if (!isPlay) {
        [self.xjPlayer play];
        isPlay = YES;
        [self.playOrPauseBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
        if ([self.delegate respondsToSelector:@selector(xjPlayerPlayOrPause:)]) {
            [self.delegate xjPlayerPlayOrPause:NO];
        }
    }else{
        [self.xjPlayer pause];
        isPlay = NO;
        [self.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        if ([self.delegate respondsToSelector:@selector(xjPlayerPlayOrPause:)]) {
            [self.delegate xjPlayerPlayOrPause:YES];
        }
    }
}
//下一个视频
- (void)nextPlayerAction{
    if ([self.delegate respondsToSelector:@selector(nextXJPlayer)]) {
        [self.delegate nextXJPlayer];
    }
}
//放大/缩小视图
- (void)fullOrSmallAction{
    if (isFull) {
        isAutoOrient = NO;
        [UIDevice setOrientation:UIInterfaceOrientationPortrait];
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        self.frame = xjPlayerFrame;
        [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
        isFull = NO;
        if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
            [self.delegate xjPlayerFullOrSmall:NO];
        }
    }else{
        isAutoOrient = NO;
        [UIDevice setOrientation:UIInterfaceOrientationLandscapeRight];
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        self.frame = self.window.bounds;
        [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
        isFull = YES;
        if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
            [self.delegate xjPlayerFullOrSmall:YES];
        }
    }
}
//slider拖动时
- (void)playSliderValueChanging:(id)sender{
    WS(weakSelf);
    UISlider *slider = (UISlider*)sender;
    [self.xjPlayer pause];
    [self.loadingView startAnimating];//缓冲没好时加上网络不佳，拖动后会加载网络
    if (slider.value == 0.0000) {
        [self.xjPlayer seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
            [weakSelf.xjPlayer play];
            [weakSelf.playOrPauseBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
            isPlay = YES;
        }];
    }
}
//slider完成拖动时
- (void)playSliderValueDidChanged:(id)sender{
    WS(weakSelf);
    UISlider *slider = (UISlider*)sender;
    CMTime changeTime = CMTimeMakeWithSeconds(slider.value,NSEC_PER_SEC);
    [self.xjPlayer removeTimeObserver:self.playbackTimeObserver];//加载网络时移除监听播放状态
    [self.xjPlayer seekToTime:changeTime completionHandler:^(BOOL finished) {
        [weakSelf.xjPlayer play];
        [self monitoringXjPlayerBack:self.xjPlayerItem];//监听播放状态
        [weakSelf.playOrPauseBtn setImage:[UIImage imageNamed:@"pause"] forState:UIControlStateNormal];
        isPlay = YES;
    }];
}

#pragma mark - kvo监听事件
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    if ([keyPath isEqualToString:@"status"]) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay) {
            
            NSLog(@"播放成功");
            [self.loadingView stopAnimating];
            [self setUserInteractionEnabled:YES];//成功才能弹出底部菜单
            
            CMTime duration = self.xjPlayerItem.duration;//获取视屏总长
            CGFloat totalSecond = playerItem.duration.value/playerItem.duration.timescale;//转换成秒
            
            self.playSlider.maximumValue = CMTimeGetSeconds(duration);//设置slider的最大值就是总时长
            self.avTotalTime = [self xjPlayerTimeStyle:totalSecond];//获取视屏总长及样式
            [self monitoringXjPlayerBack:playerItem];//监听播放状态
            
        }else if (playerItem.status == AVPlayerItemStatusUnknown){
            NSLog(@"播放未知");
        }else if (playerItem.status == AVPlayerStatusFailed){
            NSLog(@"播放失败");
        }
    }else if ([keyPath isEqualToString:@"loadedTimeRanges"]){
        
        NSTimeInterval timeInterval = [self xjPlayerAvailableDuration];
        CMTime duration = self.xjPlayerItem.duration;
        CGFloat totalDuration = CMTimeGetSeconds(duration);
        [self.loadProgressView setProgress:timeInterval/totalDuration animated:YES];
        
    }
    
}
//视屏播放完后的通知事件。从头开始播放；
- (void)xjPlayerEndPlay:(NSNotification*)notification{
    WS(weakSelf);
    [self.xjPlayer seekToTime:kCMTimeZero completionHandler:^(BOOL finished) {
        [weakSelf.playSlider setValue:0.0 animated:YES];
        [weakSelf.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        isPlay = NO;
    }];
}

//屏幕方向改变时的监听
- (void)orientChange:(NSNotification *)notification{
    UIDeviceOrientation orient = [[UIDevice currentDevice] orientation];
    switch (orient) {
            isAutoOrient = YES;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        {
            [[UIApplication sharedApplication] setStatusBarHidden:NO];
            self.frame = xjPlayerFrame;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
            isFull = NO;
            if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
                [self.delegate xjPlayerFullOrSmall:NO];
            }
            [self layoutSubviews];
        }
            break;
        case UIDeviceOrientationLandscapeLeft:      // Device oriented horizontally, home button on the right
        {
            isFull = YES;
            isAutoOrient = YES;
            [[UIApplication sharedApplication] setStatusBarHidden:YES];
            self.frame = self.window.bounds;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
            if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
                [self.delegate xjPlayerFullOrSmall:YES];
            }
            [self layoutSubviews];
        }
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
        {
            isFull = YES;
            isAutoOrient = YES;
            [[UIApplication sharedApplication] setStatusBarHidden:YES];
            self.frame = self.window.bounds;
            [self.fullOrSmallBtn setImage:[UIImage imageNamed:@"small"] forState:UIControlStateNormal];
            if ([self.delegate respondsToSelector:@selector(xjPlayerFullOrSmall:)]) {
                [self.delegate xjPlayerFullOrSmall:YES];
            }
            
            [self layoutSubviews];
        }
            break;
        default:
            break;
    }
}
#pragma mark - 自定义事件
//定义视屏时长样式
- (NSString *)xjPlayerTimeStyle:(CGFloat)time{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (time/3600>1) {
        [formatter setDateFormat:@"HH:mm:ss"];
    }else{
        [formatter setDateFormat:@"mm:ss"];
    }
    NSString *showTimeStyle = [formatter stringFromDate:date];
    return showTimeStyle;
}
//实时监听播放状态
- (void)monitoringXjPlayerBack:(AVPlayerItem *)playerItem{
    //一秒监听一次CMTimeMake(a, b),a/b表示多少秒一次；
    WS(weakSelf);
    self.playbackTimeObserver = [self.xjPlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1) queue:NULL usingBlock:^(CMTime time) {
        [weakSelf.loadingView stopAnimating];
        CGFloat currentSecond = playerItem.currentTime.value/playerItem.currentTime.timescale;//获取当前时间
        [weakSelf.playSlider setValue:currentSecond animated:YES];
        NSString *timeString = [weakSelf xjPlayerTimeStyle:currentSecond];
        weakSelf.timeLabel.text = [NSString stringWithFormat:@"00:%@/00:%@",timeString,weakSelf.avTotalTime];
    }];
}
//计算缓冲区
- (NSTimeInterval)xjPlayerAvailableDuration{
    NSArray *loadedTimeRanges = [[self.xjPlayer currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];//获取缓冲区域
    CGFloat startSeconds = CMTimeGetSeconds(timeRange.start);
    CGFloat durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds+durationSeconds;//计算缓冲进度
    return result;
}

#pragma mark - 外部接口
/**
 *  如果想自己写底部菜单，可以移除我写好的菜单；然后通过接口和代理来控制视屏;
 */
- (void)removeXJplayerBottomMenu{
    [self.bottomMenuView removeFromSuperview];
    [self removeGestureRecognizer:xjTapGesture];
}
/**
 *  暂停
 */
- (void)pause{
    [self.xjPlayer pause];
}
/**
 *  开始
 */
- (void)play{
    [self.xjPlayer play];
}
/**
 * 定位视频播放时间
 *
 * @param seconds 秒
 *
 *
 */
- (void)seekToTimeWithSeconds:(Float64)seconds {
    [self.xjPlayer seekToTime:CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC )];
}
/**
 * 取得当前播放时间
 *
 */
- (Float64)currentTime {
    return CMTimeGetSeconds([self.xjPlayer currentTime]);
}
/**
 * 取得媒体总时长
 *
 */
- (Float64)totalTime {
    return CMTimeGetSeconds(self.xjPlayerItem.duration );
}

#pragma mark - 懒加载
- (void)setXjPlayerUrl:(NSString *)xjPlayerUrl{
    _xjPlayerUrl = xjPlayerUrl;
    if (isFirst) {
        if (!isHiden) {
            self.bottomMenuView.hidden = YES;
            isHiden = YES;
        }
        if (isPlay) {
            [self.xjPlayer pause];
            [self.playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
            isPlay = NO;
        }
        [self setUserInteractionEnabled:NO];
        [self.loadingView startAnimating];
    }
    [self xjPlayerInit];
    if (!isFirst) {
        [self addToolView];
        isFirst = YES;
    }
}

- (UIView *)bottomMenuView{
    if (_bottomMenuView == nil) {
        _bottomMenuView = [[UIView alloc] init];
        _bottomMenuView.backgroundColor = [UIColor colorWithRed:50.0/255.0 green:50.0/255.0 blue:50.0/255.0 alpha:1.0];
        _bottomMenuView.hidden = YES;
        isHiden = YES;
    }
    return _bottomMenuView;
}

- (UIButton *)playOrPauseBtn{
    if (_playOrPauseBtn == nil) {
        _playOrPauseBtn = [[UIButton alloc] init];
        [_playOrPauseBtn setImage:[UIImage imageNamed:@"play"] forState:UIControlStateNormal];
        [_playOrPauseBtn addTarget:self action:@selector(playOrPauseAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playOrPauseBtn;
}

- (UIButton *)nextPlayerBtn{
    if (_nextPlayerBtn == nil) {
        _nextPlayerBtn = [[UIButton alloc] init];
        [_nextPlayerBtn setImage:[UIImage imageNamed:@"button_forward"] forState:UIControlStateNormal];
        [_nextPlayerBtn addTarget:self action:@selector(nextPlayerAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _nextPlayerBtn;
}

- (UIButton *)fullOrSmallBtn{
    if (_fullOrSmallBtn == nil) {
        _fullOrSmallBtn = [[UIButton alloc] init];
        [_fullOrSmallBtn setImage:[UIImage imageNamed:@"big"] forState:UIControlStateNormal];
        isFull = NO;
        [_fullOrSmallBtn addTarget:self action:@selector(fullOrSmallAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _fullOrSmallBtn;
}

- (UILabel *)timeLabel{
    if (_timeLabel == nil) {
        _timeLabel = [[UILabel alloc] init];
        _timeLabel.textColor = [UIColor whiteColor];
        _timeLabel.font = [UIFont systemFontOfSize:11.0];
        _timeLabel.textAlignment = NSTextAlignmentCenter;
        _timeLabel.text = @"00:00:00/00:00:00";
    }
    return _timeLabel;
}

- (UIProgressView *)loadProgressView{
    if (_loadProgressView == nil) {
        _loadProgressView = [[UIProgressView alloc] init];
        
        UIGraphicsBeginImageContextWithOptions((CGSize){1,1}, NO, 0.0f);
        UIImage *transparentImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        [self.playSlider setThumbImage:[UIImage imageNamed:@"icon_progress"] forState:UIControlStateNormal];
        [self.playSlider setMinimumTrackImage:transparentImage forState:UIControlStateNormal];
        [self.playSlider setMaximumTrackImage:transparentImage forState:UIControlStateNormal];
    }
    return _loadProgressView;
}

- (UISlider *)playSlider{
    if (_playSlider == nil) {
        _playSlider = [[UISlider alloc] init];
        _playSlider.minimumValue = 0.0;
        [_playSlider addTarget:self action:@selector(playSliderValueChanging:) forControlEvents:UIControlEventValueChanged];
        [_playSlider addTarget:self action:@selector(playSliderValueDidChanged:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playSlider;
}

- (UIActivityIndicatorView *)loadingView{
    if (_loadingView == nil) {
        _loadingView = [[UIActivityIndicatorView alloc] init];
        [_loadingView startAnimating];
    }
    return _loadingView;
}

//布局
- (void)layoutSubviews{

    self.bottomMenuView.frame = CGRectMake(0, self.height-40, self.width, 40);
    self.playOrPauseBtn.frame = CGRectMake(self.bottomMenuView.left+5, 8, 36, 23);
    if (isFull) {
        self.nextPlayerBtn.frame = CGRectMake(self.playOrPauseBtn.right, 5, 30, 30);
    }else{
        self.nextPlayerBtn.frame = CGRectMake(self.playOrPauseBtn.right+5, 5, 0, 0);
    }
    self.fullOrSmallBtn.frame = CGRectMake(self.bottomMenuView.width-35, 0, 35, self.bottomMenuView.height);
    self.timeLabel.frame = CGRectMake(self.fullOrSmallBtn.left-108, 10, 108, 20);
    self.loadProgressView.frame = CGRectMake(self.playOrPauseBtn.right+self.nextPlayerBtn.width+7, 20,self.timeLabel.left-self.playOrPauseBtn.right-self.nextPlayerBtn.width-14, 31);
    self.playSlider.frame = CGRectMake(self.playOrPauseBtn.right+self.nextPlayerBtn.width+5, 5, self.loadProgressView.width+4, 31);
    
    self.loadingView.frame = CGRectMake(self.centerX, self.centerY-20, 20, 20);
    
}

- (void)dealloc {
    [self.xjPlayerItem removeObserver:self forKeyPath:@"status" context:nil];
    [self.xjPlayerItem removeObserver:self forKeyPath:@"loadedTimeRanges" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:self.xjPlayerItem];
    [self.xjPlayer removeTimeObserver:self.playbackTimeObserver];
    [UIApplication sharedApplication].idleTimerDisabled=NO;
}

@end