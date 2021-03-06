#import "TGCallCell.h"

#import <LegacyComponents/LegacyComponents.h>

#import "TGTelegraph.h"

#import <LegacyComponents/TGLetteredAvatarView.h>
#import <LegacyComponents/TGModernButton.h>
#import "TGDialogListCellEditingControls.h"

#import "TGPresentation.h"

@interface TGCallCell ()
{
    CALayer *_separatorLayer;
 
    TGDialogListCellEditingControls *_wrapView;
    UIImageView *_typeIcon;
    TGLetteredAvatarView *_avatarView;
    
    UILabel *_nameLabel;
    UILabel *_subLabel;
    UILabel *_dateLabel;
    
    TGModernButton *_infoButton;
    
    TGCallGroup *_callGroup;
}
@end

@implementation TGCallCell

@dynamic deletePressed;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self != nil)
    {
        if (iosMajorVersion() >= 7)
        {
            self.contentView.superview.clipsToBounds = false;
        }
        
        if (iosMajorVersion() <= 6) {
            _separatorLayer = [[CALayer alloc] init];
            _separatorLayer.backgroundColor = TGSeparatorColor().CGColor;
            [self.layer addSublayer:_separatorLayer];
        }
        
        self.selectedBackgroundView = [[UIView alloc] init];
        
        _wrapView = [[TGDialogListCellEditingControls alloc] init];
        _wrapView.clipsToBounds = true;
        [_wrapView setLabelOnly:true];
        [self addSubview:_wrapView];
        
        _typeIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 34, 56)];
        _typeIcon.contentMode = UIViewContentModeCenter;
        [_wrapView addSubview:_typeIcon];
        
        _avatarView = [[TGLetteredAvatarView alloc] initWithFrame:CGRectMake(10, 7 - TGScreenPixel, 62 + TGScreenPixel, 62 + TGScreenPixel)];
        [_avatarView setSingleFontSize:18.0f doubleFontSize:18.0f useBoldFont:false];
        _avatarView.fadeTransition = cpuCoreCount() > 1;
        [_wrapView addSubview:_avatarView];
        
        _nameLabel = [[UILabel alloc] init];
        _nameLabel.font = TGSystemFontOfSize(17.0f);
        _nameLabel.textColor = UIColorRGB(0x000000);
        [_wrapView addSubview:_nameLabel];
        
        CGFloat subtitleFontSize = 14.0f;
        
        _subLabel = [[UILabel alloc] init];
        _subLabel.font = TGSystemFontOfSize(subtitleFontSize);
        _subLabel.textColor = UIColorRGB(0x8e8e93);
        [_wrapView addSubview:_subLabel];
        
        _dateLabel = [[UILabel alloc] init];
        _dateLabel.font = TGSystemFontOfSize(subtitleFontSize);
        _dateLabel.textColor = UIColorRGB(0x8e8e93);
        [_wrapView addSubview:_dateLabel];
        
        _infoButton = [[TGModernButton alloc] init];
        _infoButton.adjustsImageWhenHighlighted = false;
        [_infoButton setImage:TGImageNamed(@"CallInfoIcon") forState:UIControlStateNormal];
        [_infoButton addTarget:self action:@selector(infoButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_wrapView addSubview:_infoButton];
    }
    return self;
}

- (void)setPresentation:(TGPresentation *)presentation
{
    _presentation = presentation;
    
    [_wrapView setPresentation:presentation];
    
    self.backgroundColor = self.inSettings ? presentation.pallete.collectionMenuCellBackgroundColor : presentation.pallete.backgroundColor;
    
    [self updateName];
    _subLabel.backgroundColor = self.backgroundColor;
    _subLabel.textColor = presentation.pallete.secondaryTextColor;
    _dateLabel.textColor = presentation.pallete.secondaryTextColor;
    _dateLabel.backgroundColor = self.backgroundColor;
    [_infoButton setImage:presentation.images.callsInfoIcon forState:UIControlStateNormal];
    _typeIcon.image = presentation.images.callsOutgoingIcon;
    
    _nameLabel.backgroundColor = self.backgroundColor;
    
    _separatorLayer.backgroundColor = presentation.pallete.separatorColor.CGColor;
    self.selectedBackgroundView.backgroundColor = presentation.pallete.selectionColor;
}

- (void)setDeletePressed:(void (^)(void))deletePressed
{
    _wrapView.requestDelete = deletePressed;
}

- (void)prepareForReuse
{
    [_wrapView setExpanded:false animated:false];
    
    [super prepareForReuse];
}

- (void)updateName
{
    TGUser *peer = _callGroup.peer;
    
    UIColor *nameColor = _callGroup.failed ? _presentation.pallete.destructiveColor : _presentation.pallete.textColor;
    if (_callGroup.messages.count > 1)
    {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByTruncatingMiddle;
        
        NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:TGLocalized(@"Call.GroupFormat"), peer.displayName, [NSString stringWithFormat:@"%d", (int)_callGroup.messages.count]] attributes:@{ NSForegroundColorAttributeName: _presentation.pallete.textColor, NSFontAttributeName: _nameLabel.font, NSParagraphStyleAttributeName: style }];
        if (_callGroup.failed)
        {
            NSRange nameRange = [text.string rangeOfString:peer.displayName];
            if (nameRange.location != NSNotFound)
                [text addAttribute:NSForegroundColorAttributeName value:nameColor range:nameRange];
        }
        _nameLabel.attributedText = text;
    }
    else
    {
        _nameLabel.text = peer.displayName;
        _nameLabel.textColor = nameColor;
    }
}

- (void)setupWithCallGroup:(TGCallGroup *)group
{
    _callGroup = group;
    
    TGUser *peer = group.peer;
    
    TGMessage *message = group.message;
    
    [_wrapView setLeftButtonTypes:@[] rightButtonTypes:@[ @(TGDialogListCellEditingControlsDelete) ]];
    
    [self updateName];
    [_nameLabel sizeToFit];
    
    _dateLabel.text = [TGDateUtils stringForMessageListDate:(int)message.date];
    [_dateLabel sizeToFit];
    
    _typeIcon.hidden = !group.outgoing;
    _subLabel.text = group.displayType;
    [_subLabel sizeToFit];
    
    CGFloat diameter = TGIsPad() ? 45.0f : 40.0f;
    
    UIImage *placeholder = [self.presentation.images avatarPlaceholderWithDiameter:diameter];    
    bool animateState = false;
    if (peer.photoUrlSmall.length != 0)
    {
        _avatarView.fadeTransitionDuration = animateState ? 0.14 : 0.3;
        if (![peer.photoFullUrlSmall isEqualToString:_avatarView.currentUrl])
        {
            if (animateState)
            {
                UIImage *currentImage = [_avatarView currentImage];
                [_avatarView loadImage:peer.photoFullUrlSmall filter:TGIsPad() ? @"circle:45x45" : @"circle:40x40" placeholder:(currentImage != nil ? currentImage : placeholder) forceFade:true];
            }
            else
                [_avatarView loadImage:peer.photoFullUrlSmall filter:TGIsPad() ? @"circle:45x45" : @"circle:40x40" placeholder:placeholder];
        }
    }
    else
    {
        [_avatarView loadUserPlaceholderWithSize:CGSizeMake(diameter, diameter) uid:(int32_t)peer.uid firstName:peer.firstName lastName:peer.lastName placeholder:placeholder];
    }

    [self setNeedsLayout];
}

- (void)infoButtonPressed
{
    if (self.infoPressed != nil)
        self.infoPressed();
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat contentOffset = self.contentView.frame.origin.x;
    CGFloat contentWidth = self.contentView.frame.size.width;
    
    [_wrapView setExpandable:contentOffset <= FLT_EPSILON];
    
    static Class separatorClass = nil;
    static dispatch_once_t onceToken2;
    dispatch_once(&onceToken2, ^{
        separatorClass = NSClassFromString(TGEncodeText(@"`VJUbcmfWjfxDfmmTfqbsbupsWjfx", -1));
    });
    for (UIView *subview in self.subviews) {
        if (subview.class == separatorClass) {
            CGRect frame = subview.frame;
            if (_isLastCell) {
                frame.size.width = self.bounds.size.width;
                frame.origin.x = 0.0f;
            } else {
                if (contentOffset > FLT_EPSILON) {
                    frame.size.width = self.bounds.size.width - 122.0f;
                    frame.origin.x = 122.0f;
                } else {
                    frame.size.width = self.bounds.size.width - 86.0f;
                    frame.origin.x = 86.0f;
                }
            }
            if (!CGRectEqualToRect(subview.frame, frame)) {
                subview.frame = frame;
            }
            break;
        }
    }
    
    static CGSize screenSize;
    static CGFloat widescreenWidth;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        screenSize = TGScreenSize();
        widescreenWidth = MAX(screenSize.width, screenSize.height);
    });
    
    CGSize rawSize = self.frame.size;
    CGSize size = rawSize;
    if (!TGIsPad())
    {
        if ([TGViewController hasTallScreen])
        {
            size.width = contentWidth;
        }
        else
        {
            if (rawSize.width >= widescreenWidth - FLT_EPSILON)
                size.width = screenSize.height - contentOffset;
            else
                size.width = screenSize.width - contentOffset;
        }
    }
    else
        size.width = rawSize.width - contentOffset;
    
    _wrapView.frame = CGRectMake(contentOffset, 0.0f, size.width, size.height);
    
    CGFloat separatorHeight = TGScreenPixel;
    CGFloat separatorInset = 86.0f;

    _separatorLayer.frame = CGRectMake(separatorInset, self.frame.size.height - separatorHeight, self.frame.size.width - separatorInset, separatorHeight);

    CGRect frame = self.selectedBackgroundView.frame;
    frame.origin.y = -1;
    frame.size.height = self.frame.size.height + 1;
    self.selectedBackgroundView.frame = frame;
    
    CGFloat leftPadding = TGIsPad() ? 36.0f : 34.0f;
    if (self.editing)
        leftPadding += 2;
    
    CGRect avatarFrame = CGRectMake(leftPadding, 8.0f, 40, 40);
    if (TGIsPad())
        avatarFrame = CGRectMake(leftPadding, 6.0f, 45, 45);
    
    if (!CGRectEqualToRect(_avatarView.frame, avatarFrame))
        _avatarView.frame = avatarFrame;
    
    leftPadding = CGRectGetMaxX(avatarFrame) + 12.0f;
    
    _dateLabel.frame = CGRectMake(size.width - _dateLabel.frame.size.width - 48.0f, 20.0f, _dateLabel.frame.size.width, _dateLabel.frame.size.height);
    
    _nameLabel.frame = CGRectMake(leftPadding, 8.0f, _dateLabel.frame.origin.x - leftPadding - 8.0f, _nameLabel.frame.size.height);
    _subLabel.frame = CGRectMake(leftPadding, 31.0f, _dateLabel.frame.origin.x - leftPadding - 8.0f, _subLabel.frame.size.height);
    
    _infoButton.frame = CGRectMake(size.width - 48.0f, 0, 48.0f, 56.0f);
}

- (void)setIsLastCell:(bool)isLastCell {
    if (_isLastCell != isLastCell) {
        _isLastCell = isLastCell;
        [self setNeedsLayout];
    }
}

- (bool)isEditingControlsExpanded {
    return [_wrapView isExpanded];
}

- (void)setEditingConrolsExpanded:(bool)expanded animated:(bool)animated {
    [_wrapView setExpanded:expanded animated:animated];
}

@end


@implementation TGCallGroup

- (instancetype)initWithMessages:(NSArray *)messages peer:(TGUser *)peer failed:(bool)failed
{
    self = [super init];
    if (self != nil)
    {
        _messages = messages;
        _peer = peer;
        _failed = failed;
    }
    return self;
}

- (NSString *)identifier
{
    return [NSString stringWithFormat:@"%d_%d", _peer.uid, self.message.mid];
}

- (TGMessage *)message
{
    return _messages.firstObject;
}

- (bool)outgoing
{
    for (TGMessage *message in _messages)
    {
        if (message.outgoing)
            return true;
    }
    return false;
}

typedef enum {
    TGCallDisplayTypeOutgoing,
    TGCallDisplayTypeIncoming,
    TGCallDisplayTypeCancelled,
    TGCallDisplayTypeMissed
} TGCallDisplayType;

- (NSString *)stringForDisplayType:(TGCallDisplayType)type
{
    switch (type)
    {
        case TGCallDisplayTypeOutgoing:
            return TGLocalized(@"Notification.CallOutgoingShort");
            
        case TGCallDisplayTypeIncoming:
            return TGLocalized(@"Notification.CallIncomingShort");
            
        case TGCallDisplayTypeCancelled:
            return TGLocalized(@"Notification.CallCanceledShort");
            
        case TGCallDisplayTypeMissed:
            return TGLocalized(@"Notification.CallMissedShort");
            
        default:
            return nil;
    }
}

- (NSString *)displayType
{
    if (self.failed)
        return TGLocalized(@"Notification.CallMissedShort");
    
    NSString *finalType = @"";
    NSMutableSet *types = [[NSMutableSet alloc] init];
    for (TGMessage *message in self.messages)
    {
        bool outgoing = message.outgoing;
        int reason = [message.actionInfo.actionData[@"reason"] intValue];
        bool missed = reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
        
        TGCallDisplayType type = missed ? (outgoing ? TGCallDisplayTypeCancelled : TGCallDisplayTypeMissed) : (outgoing ? TGCallDisplayTypeOutgoing : TGCallDisplayTypeIncoming);
        
        [types addObject:@(type)];
    }
    
    if (types.count > 1)
        [types removeObject:@(TGCallDisplayTypeCancelled)];
    
    NSArray *typesArray = [types sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"self" ascending:true]]];
    for (NSNumber *typeValue in typesArray)
    {
        NSString *type = [self stringForDisplayType:(TGCallDisplayType)typeValue.integerValue];
        if (finalType.length == 0)
            finalType = type;
        else
            finalType = [finalType stringByAppendingFormat:@", %@", type];
    }
    
    if (self.messages.count == 1)
    {
        TGMessage *message = self.message;
        int reason = [message.actionInfo.actionData[@"reason"] intValue];
        bool missed = reason == TGCallDiscardReasonMissed || reason == TGCallDiscardReasonBusy;
        
        int callDuration = [message.actionInfo.actionData[@"duration"] intValue];
        NSString *duration = missed || callDuration < 1 ? nil : [TGStringUtils stringForShortCallDurationSeconds:callDuration];
        finalType = duration != nil ? [NSString stringWithFormat:TGLocalized(@"Notification.CallTimeFormat"), finalType, duration] : finalType;
    }
    
    return finalType;
}

@end
