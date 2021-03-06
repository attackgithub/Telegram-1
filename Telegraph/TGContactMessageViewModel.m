#import "TGContactMessageViewModel.h"

#import <LegacyComponents/LegacyComponents.h>

#import "TGModernConversationItem.h"
#import "TGModernView.h"

#import "TGTextMessageBackgroundViewModel.h"
#import "TGModernFlatteningViewModel.h"
#import "TGModernTextViewModel.h"
#import "TGReusableLabel.h"
#import "TGModernLabelViewModel.h"
#import "TGModernDateViewModel.h"
#import "TGModernClockProgressViewModel.h"
#import "TGModernRemoteImageViewModel.h"
#import "TGModernButtonViewModel.h"
#import "TGModernColorViewModel.h"

#import "TGArticleWebpageFooterModel.h"

#import "TGModernLetteredAvatarViewModel.h"

#import <LegacyComponents/TGDoubleTapGestureRecognizer.h>

#import "TGReplyHeaderModel.h"

#import "TGMessageViewsViewModel.h"

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGVCard.h"
#import "TGDatabase.h"

#import "TGMessageReplyButtonsModel.h"

#import "TGPresentation.h"

@interface TGContactMessageViewModel () <UIGestureRecognizerDelegate, TGDoubleTapGestureRecognizerDelegate>
{
    TGTextMessageBackgroundViewModel *_backgroundModel;
    TGModernFlatteningViewModel *_contentModel;
    
    TGModernTextViewModel *_authorNameModel;
    TGModernTextViewModel *_forwardedHeaderModel;
    TGReplyHeaderModel *_replyHeaderModel;
    
    TGModernLabelViewModel *_contactNameModel;
    TGModernTextViewModel *_contactTextModel;
    TGModernLetteredAvatarViewModel *_contactAvatarModel;
    TGModernButtonViewModel *_contactButtonModel;
    
    TGModernButtonViewModel *_actionButtonModel;
    
    TGModernDateViewModel *_dateModel;
    TGModernClockProgressViewModel *_progressModel;
    TGModernImageViewModel *_checkFirstModel;
    TGModernImageViewModel *_checkSecondModel;
    bool _checkFirstEmbeddedInContent;
    bool _checkSecondEmbeddedInContent;
    TGModernImageViewModel *_unsentButtonModel;
    
    TGMessage *_message;
    
    bool _savedMessage;
    bool _incoming;
    TGMessageDeliveryState _deliveryState;
    bool _read;
    int32_t _date;
    TGUser *_contact;
    
    bool _hasAvatar;
    
    int64_t _forwardedPeerId;
    int32_t _forwardedMessageId;
    
    TGDoubleTapGestureRecognizer *_boundDoubleTapRecognizer;
    UITapGestureRecognizer *_unsentButtonTapRecognizer;
    
    bool _contactAdded;
    
    CGSize _boundOffset;
    
    int32_t _replyMessageId;
    
    TGMessageViewCountContentProperty *_messageViews;
    TGMessageViewsViewModel *_messageViewsModel;
    
    TGModernTextViewModel *_authorSignatureModel;
    
    NSString *_authorSignature;
    TGUser *_viaUser;
    
    TGMessageReplyButtonsModel *_replyButtonsModel;
    SMetaDisposable *_callbackButtonInProgressDisposable;
    NSDictionary *_callbackButtonInProgress;
    TGBotReplyMarkup *_replyMarkup;
}

@end

@implementation TGContactMessageViewModel

- (instancetype)initWithMessage:(TGMessage *)message contact:(TGUser *)contact authorPeer:(id)authorPeer context:(TGModernViewContext *)context viaUser:(TGUser *)viaUser
{
    self = [super initWithAuthorPeer:authorPeer context:context];
    if (self != nil)
    {
        _callbackButtonInProgressDisposable = [[SMetaDisposable alloc] init];
        
        static TGTelegraphConversationMessageAssetsSource *assetsSource = nil;
        static dispatch_once_t onceToken1;
        dispatch_once(&onceToken1, ^
        {
            assetsSource = [TGTelegraphConversationMessageAssetsSource instance];
        });
        
        _needsEditingCheckButton = true;
        
        bool isChannel = [authorPeer isKindOfClass:[TGConversation class]];
        
        _contact = [contact copy];
        TGForwardedMessageMediaAttachment *forwardAttachment = nil;
        TGContactMediaAttachment *contactAttachment = nil;
        for (TGMediaAttachment *attachment in message.mediaAttachments)
        {
            if (attachment.type == TGContactMediaAttachmentType)
            {
                contactAttachment = (TGContactMediaAttachment *)attachment;
                _contact.customProperties = @{ @"contact": contactAttachment };
            } else if (attachment.type == TGForwardedMessageMediaAttachmentType)
            {
                forwardAttachment = (TGForwardedMessageMediaAttachment *)attachment;
            }
        }
        _savedMessage = forwardAttachment != nil && context.isSavedMessages && forwardAttachment.forwardSourcePeerId != message.cid;
        _message = message;
        _mid = message.mid;
        _authorPeerId = message.fromUid;
        _incoming = !message.outgoing;
        _incomingAppearance = _incoming || isChannel || _savedMessage;
        _deliveryState = message.deliveryState;
        _read = ![_context isMessageUnread:message];
        _date = (int32_t)message.date;
        
        _messageViews = message.viewCount;
        
        _backgroundModel = [[TGTextMessageBackgroundViewModel alloc] initWithType:_incomingAppearance ? TGTextMessageBackgroundIncoming : TGTextMessageBackgroundOutgoing context:context];
        _backgroundModel.blendMode = kCGBlendModeCopy;
        _backgroundModel.skipDrawInContext = true;
        [self addSubmodel:_backgroundModel];
        
        if (isChannel) {
            [_backgroundModel setPartialMode:false];
        }
        
        _contentModel = [[TGModernFlatteningViewModel alloc] initWithContext:_context];
        _contentModel.viewUserInteractionDisabled = true;
        [self addSubmodel:_contentModel];
        
        if (authorPeer != nil)
        {
            NSString *title = @"";
            if ([authorPeer isKindOfClass:[TGUser class]]) {
                title = ((TGUser *)authorPeer).displayName;
                _hasAvatar = true;
            } else if ([authorPeer isKindOfClass:[TGConversation class]]) {
                title = ((TGConversation *)authorPeer).chatTitle;
                if (context.isAdminLog || context.isSavedMessages || context.isFeed) {
                    _hasAvatar = true;
                }
            }
            _authorNameModel = [[TGModernTextViewModel alloc] initWithText:title font:[assetsSource messageAuthorNameFont]];
            [_contentModel addSubmodel:_authorNameModel];
            
            static CTFontRef dateFont = NULL;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                if (iosMajorVersion() >= 7) {
                    dateFont = CTFontCreateWithFontDescriptor((__bridge CTFontDescriptorRef)[TGItalicSystemFontOfSize(12.0f) fontDescriptor], 0.0f, NULL);
                } else {
                    UIFont *font = TGItalicSystemFontOfSize(12.0f);
                    dateFont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, nil);
                }
            });
            _authorSignatureModel = [[TGModernTextViewModel alloc] initWithText:@"" font:dateFont];
            _authorSignatureModel.ellipsisString = @"\u2026,";
            _authorSignatureModel.textColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingDateColor : _context.presentation.pallete.chatOutgoingDateColor;
            [_contentModel addSubmodel:_authorSignatureModel];
        }
        
        TGVCard *vcard = [[TGVCard alloc] initWithString:contactAttachment.vcard];
        bool usedOrganization = false;
        if (!contact.hasAnyName && vcard.organization.value.length > 0)
        {
            contact.firstName = vcard.organization.value;
            usedOrganization = true;
        }
        
        _contactAvatarModel = [[TGModernLetteredAvatarViewModel alloc] initWithSize:CGSizeMake(40, 40) placeholder:[_context.presentation.images avatarPlaceholderWithDiameter:40.0f]];
        if (contact.photoUrlSmall.length != 0)
            [_contactAvatarModel setAvatarUri:contact.photoFullUrlSmall];
        else
            [_contactAvatarModel setAvatarFirstName:contact.firstName lastName:contact.lastName uid:contact.uid];
        
        _contactAvatarModel.skipDrawInContext = true;
        _contactAvatarModel.viewUserInteractionDisabled = true;
        [self addSubmodel:_contactAvatarModel];
        
        _contactNameModel = [[TGModernLabelViewModel alloc] initWithText:contact.displayName textColor:_incomingAppearance ? context.presentation.pallete.chatIncomingAccentColor : context.presentation.pallete.chatOutgoingAccentColor font:[assetsSource messageForwardPhoneNameFont] maxWidth:155.0f];
        [_contentModel addSubmodel:_contactNameModel];
        
        const NSUInteger limit = 5;
        NSMutableArray *lines = [[NSMutableArray alloc] init];
        if (vcard.phones.values.count > 0)
        {
            for (TGVCardValueArrayItem *phone in vcard.phones.values)
            {
                if (lines.count == limit)
                    break;
                
                NSString *phoneValue = phone.value;
                NSCharacterSet *letterChars = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
                if ([phoneValue.uppercaseString rangeOfCharacterFromSet:letterChars].location == NSNotFound) {
                    phoneValue = [TGPhoneUtils formatPhone:phoneValue forceInternational:contact.uid != 0];
                }
                [lines addObject:phoneValue];
            }
        }
        else if (contact.phoneNumber != nil)
        {
            NSString *phoneValue = contact.phoneNumber.length > 0 ? contact.phoneNumber : contactAttachment.phoneNumber;
            NSCharacterSet *letterChars = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
            if ([phoneValue.uppercaseString rangeOfCharacterFromSet:letterChars].location == NSNotFound) {
                phoneValue = [TGPhoneUtils formatPhone:phoneValue forceInternational:contact.uid != 0];
            }
            if (phoneValue != nil)
                [lines addObject:phoneValue];
        }
        
        for (TGVCardValueArrayItem *email in vcard.emails.values)
        {
            if (lines.count == limit)
                break;
            
            [lines addObject:(NSString *)email.value];
        }
        
        if (!usedOrganization && lines.count != limit && vcard.organization.value.length > 0)
            [lines addObject:vcard.organization.value];
        
        _contactTextModel = [[TGModernTextViewModel alloc] initWithText:[lines componentsJoinedByString:@"\n"] font:[assetsSource messageForwardPhoneFont]];
        _contactTextModel.textColor = _incomingAppearance ? context.presentation.pallete.chatIncomingTextColor : context.presentation.pallete.chatOutgoingTextColor;
        _contactTextModel.layoutFlags = TGReusableLabelLayoutMultiline;
        [_contentModel addSubmodel:_contactTextModel];
        
        UIImage *icon = _incomingAppearance ? TGTintedImage(TGImageNamed(@"ModernMessageContactAdd_Incoming.png"), context.presentation.pallete.chatIncomingAccentColor) : TGTintedImage(TGImageNamed(@"ModernMessageContactAdd_Incoming.png"), context.presentation.pallete.chatOutgoingAccentColor);
        
        _contactButtonModel = [[TGModernButtonViewModel alloc] init];
        _contactButtonModel.image = icon;
        _contactButtonModel.modernHighlight = true;
        [self addSubmodel:_contactButtonModel];
        
        int daytimeVariant = 0;
        NSString *dateText = [TGDateUtils stringForShortTime:(int)message.date daytimeVariant:&daytimeVariant];
        _dateModel = [[TGModernDateViewModel alloc] initWithText:dateText textColor:_incomingAppearance ? _context.presentation.pallete.chatIncomingDateColor : _context.presentation.pallete.chatOutgoingDateColor daytimeVariant:daytimeVariant];
        [_contentModel addSubmodel:_dateModel];
        
        if (_messageViews != nil) {
            _messageViewsModel = [[TGMessageViewsViewModel alloc] init];
            _messageViewsModel.presentation = context.presentation;
            _messageViewsModel.type = _incomingAppearance ? TGMessageViewsViewTypeIncoming : TGMessageViewsViewTypeOutgoing;
            _messageViewsModel.count = _messageViews.viewCount;
            [self addSubmodel:_messageViewsModel];
            _messageViewsModel.hidden = _deliveryState != TGMessageDeliveryStateDelivered;
        }
        
        if (!_incoming)
        {
            _checkFirstModel = [[TGModernImageViewModel alloc] initWithImage:_context.presentation.images.chatDeliveredIcon];
            _checkSecondModel = [[TGModernImageViewModel alloc] initWithImage:_context.presentation.images.chatReadIcon];
            
            if (_deliveryState == TGMessageDeliveryStatePending)
            {
                _progressModel = [[TGModernClockProgressViewModel alloc] initWithType:_incomingAppearance ? TGModernClockProgressTypeIncomingClock : TGModernClockProgressTypeOutgoingClock];
                _progressModel.presentation = context.presentation;
                [self addSubmodel:_progressModel];
                
                if (!_incomingAppearance) {
                    [self addSubmodel:_checkFirstModel];
                    [self addSubmodel:_checkSecondModel];
                }
                _checkFirstModel.alpha = 0.0f;
                _checkSecondModel.alpha = 0.0f;
            }
            else if (_deliveryState == TGMessageDeliveryStateFailed)
            {
                [self addSubmodel:[self unsentButtonModel]];
            }
            else if (_deliveryState == TGMessageDeliveryStateDelivered)
            {
                if (!_incomingAppearance) {
                    [_contentModel addSubmodel:_checkFirstModel];
                }
                _checkFirstEmbeddedInContent = true;
                
                if (_read)
                {
                    if (!_incomingAppearance) {
                        [_contentModel addSubmodel:_checkSecondModel];
                    }
                    _checkSecondEmbeddedInContent = true;
                }
                else
                {
                    if (!_incomingAppearance) {
                        [self addSubmodel:_checkSecondModel];
                    }
                    _checkSecondModel.alpha = 0.0f;
                }
            }
        }
        
        NSDictionary *button = [TGArticleWebpageFooterModel buttonForType:@"viewContactDetails" context:context];
        _actionButtonModel = [[TGModernButtonViewModel alloc] init];
        _actionButtonModel.image = _incomingAppearance ? button[@"incoming"] : button[@"outgoing"];
        _actionButtonModel.highlightedImage = _incomingAppearance ? button[@"incomingHighlighted"] : button[@"outgoingHighlighted"];
        _actionButtonModel.backgroundImage = _incomingAppearance ? button[@"incomingBg"] : button[@"outgoingBg"];
        _actionButtonModel.highlightedBackgroundImage = _incomingAppearance ? button[@"incomingSolidBg"] : button[@"outgoingSolidBg"];
        _actionButtonModel.skipDrawInContext = true;

        __weak TGContactMessageViewModel *weakSelf = self;
        _actionButtonModel.pressed = ^{
            __strong TGContactMessageViewModel *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf->_context.companionHandle requestAction:@"openVCard" options:@{@"contact": strongSelf->_contact}];
            }
        };
        [self addSubmodel:_actionButtonModel];
        
        TGBotReplyMarkup *replyMarkup = message.replyMarkup;
        if (replyMarkup != nil && replyMarkup.isInline) {
            _replyMarkup = replyMarkup;
            _replyButtonsModel = [[TGMessageReplyButtonsModel alloc] initWithContext:context];
            __weak TGContactMessageViewModel *weakSelf = self;
            _replyButtonsModel.buttonActivated = ^(TGBotReplyMarkupButton *button, NSInteger index) {
                __strong TGContactMessageViewModel *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{@"mid": @(strongSelf->_mid), @"command": button.text}];
                    if (button.action != nil) {
                        dict[@"action"] = button.action;
                    }
                    dict[@"index"] = @(index);
                    [strongSelf->_context.companionHandle requestAction:@"activateCommand" options:dict];
                }
            };
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:false];
            [self addSubmodel:_replyButtonsModel];
        }
        
        _viaUser = viaUser;
    }
    return self;
}

- (void)dealloc {
    [_callbackButtonInProgressDisposable dispose];
}

- (TGModernImageViewModel *)unsentButtonModel
{
    if (_unsentButtonModel == nil)
    {
        UIImage *image = _context.presentation.images.chatUnsentIcon;
        _unsentButtonModel = [[TGModernImageViewModel alloc] initWithImage:image];
        _unsentButtonModel.frame = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
        _unsentButtonModel.extendedEdges = UIEdgeInsetsMake(6, 6, 6, 6);
    }
    
    return _unsentButtonModel;
}

- (void)setAuthorNameColor:(UIColor *)authorNameColor
{
    _authorNameModel.textColor = authorNameColor;
}

- (void)setAuthorSignature:(NSString *)authorSignature {
    _authorSignatureModel.text = [authorSignature stringByAppendingString:@","];
    _authorSignature = authorSignature;
}

- (void)setForwardHeader:(id)forwardPeer forwardAuthor:(id)forwardAuthor messageId:(int32_t)messageId
{
    _forwardedMessageId = messageId;
    
    if (_forwardedHeaderModel == nil)
    {
        static NSRange formatNameRange;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            formatNameRange = [TGLocalized(@"Message.ForwardedMessage") rangeOfString:@"%@"];
        });
        
        NSString *title = @"";
        if ([forwardPeer isKindOfClass:[TGUser class]]) {
            _forwardedPeerId = ((TGUser *)forwardPeer).uid;
            title = ((TGUser *)forwardPeer).displayName;
        } else if ([forwardPeer isKindOfClass:[TGConversation class]] ) {
            _forwardedPeerId = ((TGConversation *)forwardPeer).conversationId;
            title = ((TGConversation *)forwardPeer).chatTitle;
        }
        
        if ([forwardAuthor isKindOfClass:[TGUser class]]) {
            title = [[NSString alloc] initWithFormat:@"%@ (%@)", title, ((TGUser *)forwardAuthor).displayName];
        }
        
        NSString *text = [[NSString alloc] initWithFormat:TGLocalized(@"Message.ForwardedMessage"), title];
        
        _forwardedHeaderModel = [[TGModernTextViewModel alloc] initWithText:text font:[[TGTelegraphConversationMessageAssetsSource instance] messageForwardTitleFont]];
        _forwardedHeaderModel.textColor = _incomingAppearance ? _context.presentation.pallete.chatIncomingAccentColor : _context.presentation.pallete.chatOutgoingAccentColor;
        _forwardedHeaderModel.layoutFlags = TGReusableLabelLayoutMultiline;
        if (formatNameRange.location != NSNotFound && title.length != 0)
        {
            NSArray *fontAttributes = [[NSArray alloc] initWithObjects:(__bridge id)[[TGTelegraphConversationMessageAssetsSource instance] messageForwardNameFont], (NSString *)kCTFontAttributeName, nil];
            NSRange range = NSMakeRange(formatNameRange.location, title.length);
            _forwardedHeaderModel.additionalAttributes = [[NSArray alloc] initWithObjects:[[NSValue alloc] initWithBytes:&range objCType:@encode(NSRange)], fontAttributes, nil];
        }
        
        [_contentModel addSubmodel:_forwardedHeaderModel];
    }
}

- (void)setReplyHeader:(TGMessage *)replyHeader peer:(id)peer
{
    _replyMessageId = replyHeader.mid;
    _replyHeaderModel = [TGContentBubbleViewModel replyHeaderModelFromMessage:replyHeader peer:peer incoming:_incomingAppearance system:false presentation:_context.presentation];
    if (_replyHeaderModel != nil)
        [_contentModel addSubmodel:_replyHeaderModel];
}

- (void)setTemporaryHighlighted:(bool)temporaryHighlighted viewStorage:(TGModernViewStorage *)__unused viewStorage
{
    if (temporaryHighlighted)
        [_backgroundModel setHighlightedIfBound];
    else
        [_backgroundModel clearHighlight];
}

- (void)updateMessageAttributes {
    [super updateMessageAttributes];
    
    bool previousRead = _read;
    _read = ![_context isMessageUnread:_message];
    
    if (_read != previousRead) {
        if (_read) {
            _checkSecondModel.alpha = 1.0f;
            
            if (!previousRead && [_checkSecondModel boundView] != nil) {
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                animation.fromValue = @(1.3f);
                animation.toValue = @(1.0f);
                animation.duration = 0.1;
                animation.removedOnCompletion = true;
                
                [[_checkSecondModel boundView].layer addAnimation:animation forKey:@"transform.scale"];
            }
        }
    }
}

- (void)updateMessage:(TGMessage *)message viewStorage:(TGModernViewStorage *)viewStorage sizeUpdated:(bool *)sizeUpdated
{
    [super updateMessage:message viewStorage:viewStorage sizeUpdated:sizeUpdated];
    
    _mid = message.mid;
    _message = message;
    
    if (_messageViewsModel != nil) {
        _messageViewsModel.count = message.viewCount.viewCount;
    }
    
    bool messageUnread = [_context isMessageUnread:message];
    if (_deliveryState != message.deliveryState || (!_incoming && _read != !messageUnread))
    {
        TGMessageDeliveryState previousDeliveryState = _deliveryState;
        _deliveryState = message.deliveryState;
        
        if (_messageViewsModel != nil) {
            _messageViewsModel.hidden = _deliveryState != TGMessageDeliveryStateDelivered;
        }
        
        bool previousRead = _read;
        _read = !messageUnread;
        
        if (_date != (int32_t)message.date)
        {
            _date = (int32_t)message.date;
            
            int daytimeVariant = 0;
            NSString *dateText = [TGDateUtils stringForShortTime:(int)message.date daytimeVariant:&daytimeVariant];
            [_dateModel setText:dateText daytimeVariant:daytimeVariant];
        }
        
        if (_deliveryState == TGMessageDeliveryStateDelivered)
        {
            if (_progressModel != nil)
            {
                [self removeSubmodel:_progressModel viewStorage:viewStorage];
                _progressModel = nil;
            }
            
            _checkFirstModel.alpha = 1.0f;
            
            if (previousDeliveryState == TGMessageDeliveryStatePending && [_checkFirstModel boundView] != nil)
            {
                CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                animation.fromValue = @(1.3f);
                animation.toValue = @(1.0f);
                animation.duration = 0.1;
                animation.removedOnCompletion = true;
                
                [[_checkFirstModel boundView].layer addAnimation:animation forKey:@"transform.scale"];
            }
            
            if (_read)
            {
                _checkSecondModel.alpha = 1.0f;
                
                if (!previousRead && [_checkSecondModel boundView] != nil)
                {
                    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
                    animation.fromValue = @(1.3f);
                    animation.toValue = @(1.0f);
                    animation.duration = 0.1;
                    animation.removedOnCompletion = true;
                    
                    [[_checkSecondModel boundView].layer addAnimation:animation forKey:@"transform.scale"];
                }
            }
            
            if (_unsentButtonModel != nil)
            {
                [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                _unsentButtonModel = nil;
            }
        }
        else if (_deliveryState == TGMessageDeliveryStateFailed)
        {
            if (_progressModel != nil)
            {
                [self removeSubmodel:_progressModel viewStorage:viewStorage];
                _progressModel = nil;
            }
            
            if (_checkFirstModel != nil)
            {
                if (_checkFirstEmbeddedInContent)
                {
                    [_contentModel removeSubmodel:_checkFirstModel viewStorage:viewStorage];
                    [_contentModel setNeedsSubmodelContentsUpdate];
                }
                else
                    [self removeSubmodel:_checkFirstModel viewStorage:viewStorage];
            }
            
            if (_checkSecondModel != nil)
            {
                if (_checkSecondEmbeddedInContent)
                {
                    [_contentModel removeSubmodel:_checkSecondModel viewStorage:viewStorage];
                    [_contentModel setNeedsSubmodelContentsUpdate];
                }
                else
                    [self removeSubmodel:_checkSecondModel viewStorage:viewStorage];
            }
            
            if (_unsentButtonModel == nil)
            {
                [self addSubmodel:[self unsentButtonModel]];
                if ([_contentModel boundView] != nil)
                    [_unsentButtonModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                _unsentButtonModel.frame = CGRectOffset(_unsentButtonModel.frame, self.frame.size.width + _unsentButtonModel.frame.size.width, self.frame.size.height - _unsentButtonModel.frame.size.height - ((_collapseFlags & TGModernConversationItemCollapseBottom) ? 5 : 6));
                
                _unsentButtonTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unsentButtonTapGesture:)];
                [[_unsentButtonModel boundView] addGestureRecognizer:_unsentButtonTapRecognizer];
            }
            
            if (self.frame.size.width > FLT_EPSILON)
            {
                if ([_contentModel boundView] != nil)
                {
                    [UIView animateWithDuration:0.2 animations:^
                     {
                         [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                     }];
                }
                else
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
            }
            
            [_contentModel updateSubmodelContentsIfNeeded];
        }
        else if (_deliveryState == TGMessageDeliveryStatePending)
        {
            if (_progressModel == nil)
            {
                TGMessageViewModelLayoutConstants const *layoutConstants = TGGetMessageViewModelLayoutConstants();
                
                bool hasSignature = false;
                if (_authorSignature.length != 0) {
                    hasSignature = true;
                }
                CGFloat signatureSize = (hasSignature ? (_authorSignatureModel.frame.size.width + 8.0f) : 0.0f);
                
                CGFloat unsentOffset = 0.0f;
                if (!_incomingAppearance && previousDeliveryState == TGMessageDeliveryStateFailed)
                    unsentOffset = 29.0f;
                
                _progressModel = [[TGModernClockProgressViewModel alloc] initWithType:_incomingAppearance ? TGModernClockProgressTypeIncomingClock : TGModernClockProgressTypeOutgoingClock];
                _progressModel.presentation = _context.presentation;
                if (_incomingAppearance) {
                    _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - _dateModel.frame.size.width - 27.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
                } else {
                    _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - 23.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
                }
                
                [self addSubmodel:_progressModel];
                
                if ([_contentModel boundView] != nil)
                {
                    [_progressModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                }
            }
            
            [_contentModel removeSubmodel:_checkFirstModel viewStorage:viewStorage];
            [_contentModel removeSubmodel:_checkSecondModel viewStorage:viewStorage];
            _checkFirstEmbeddedInContent = false;
            _checkSecondEmbeddedInContent = false;
            
            if (![self containsSubmodel:_checkFirstModel])
            {
                if (!_incomingAppearance) {
                    [self addSubmodel:_checkFirstModel];
                
                    if ([_contentModel boundView] != nil)
                        [_checkFirstModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
                }
            }
            if (![self containsSubmodel:_checkSecondModel])
            {
                [self addSubmodel:_checkSecondModel];
                
                if ([_contentModel boundView] != nil)
                    [_checkSecondModel bindViewToContainer:[_contentModel boundView].superview viewStorage:viewStorage];
            }
            
            _checkFirstModel.alpha = 0.0f;
            _checkSecondModel.alpha = 0.0f;
            
            if (_unsentButtonModel != nil)
            {
                UIView<TGModernView> *unsentView = [_unsentButtonModel boundView];
                if (unsentView != nil)
                {
                    [unsentView removeGestureRecognizer:_unsentButtonTapRecognizer];
                    _unsentButtonTapRecognizer = nil;
                }
                
                if (unsentView != nil)
                {
                    [viewStorage allowResurrectionForOperations:^
                     {
                         [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                         
                         UIView *restoredView = [viewStorage dequeueViewWithIdentifier:[unsentView viewIdentifier] viewStateIdentifier:[unsentView viewStateIdentifier]];
                         
                         if (restoredView != nil)
                         {
                             [[_contentModel boundView].superview addSubview:restoredView];
                             
                             [UIView animateWithDuration:0.2 animations:^
                              {
                                  restoredView.frame = CGRectOffset(restoredView.frame, restoredView.frame.size.width + 9, 0.0f);
                                  restoredView.alpha = 0.0f;
                              } completion:^(__unused BOOL finished)
                              {
                                  [viewStorage enqueueView:restoredView];
                              }];
                         }
                     }];
                }
                else
                    [self removeSubmodel:_unsentButtonModel viewStorage:viewStorage];
                
                _unsentButtonModel = nil;
            }
            
            if (self.frame.size.width > FLT_EPSILON)
            {
                if ([_contentModel boundView] != nil)
                {
                    [UIView animateWithDuration:0.2 animations:^
                     {
                         [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
                     }];
                }
                else
                    [self layoutForContainerSize:CGSizeMake(self.frame.size.width, 0.0f)];
            }
            
            [_contentModel setNeedsSubmodelContentsUpdate];
            [_contentModel updateSubmodelContentsIfNeeded];
        }
    }
    
    for (id attachment in message.mediaAttachments) {
        if ([attachment isKindOfClass:[TGContactMediaAttachment class]]) {
            TGContactMediaAttachment *contactMedia = attachment;
            TGUser *contact = nil;
            if (contactMedia.uid != 0) {
                contact = [TGDatabaseInstance() loadUser:contactMedia.uid];
            } else {
                contact = [[TGUser alloc] init];
            }
            contact.firstName = contactMedia.firstName;
            contact.lastName = contactMedia.lastName;
            
            if (![_contact isEqualToUser:contact]) {
                //_contact = contact;
                
                if (contact.photoUrlSmall.length != 0)
                    [_contactAvatarModel setAvatarUri:contact.photoFullUrlSmall];
                else
                    [_contactAvatarModel setAvatarFirstName:contact.firstName lastName:contact.lastName uid:contact.uid];
            }
            
            break;
        }
    }
    
    TGBotReplyMarkup *replyMarkup = message.replyMarkup != nil && message.replyMarkup.isInline ? message.replyMarkup : nil;
    if (!TGObjectCompare(_replyMarkup, replyMarkup)) {
        _replyMarkup = replyMarkup;
        
        if (_replyButtonsModel == nil) {
            _replyButtonsModel = [[TGMessageReplyButtonsModel alloc] initWithContext:_context];
            __weak TGContactMessageViewModel *weakSelf = self;
            _replyButtonsModel.buttonActivated = ^(TGBotReplyMarkupButton *button, NSInteger index) {
                __strong TGContactMessageViewModel *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:@{@"mid": @(strongSelf->_mid), @"command": button.text}];
                    if (button.action != nil) {
                        dict[@"action"] = button.action;
                    }
                    dict[@"index"] = @(index);
                    [strongSelf->_context.companionHandle requestAction:@"activateCommand" options:dict];
                }
            };
            
            [self addSubmodel:_replyButtonsModel];
        }
        if (_backgroundModel.boundView != nil) {
            [_replyButtonsModel unbindView:viewStorage];
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:false];
            [_replyButtonsModel bindViewToContainer:_backgroundModel.boundView.superview viewStorage:viewStorage];
        } else {
            [_replyButtonsModel setReplyMarkup:replyMarkup hasReceipt:false];
        }
        if (sizeUpdated) {
            *sizeUpdated = true;
        }
    }
}

- (void)updateMediaAvailability:(bool)mediaIsAvailable viewStorage:(TGModernViewStorage *)viewStorage delayDisplay:(bool)delayDisplay
{
    [super updateMediaAvailability:mediaIsAvailable viewStorage:viewStorage delayDisplay:delayDisplay];
    
    if (mediaIsAvailable != _contactAdded)
    {
        _contactAdded = mediaIsAvailable;
        
        if (!mediaIsAvailable)
            _contactButtonModel.alpha = 1.0f;
        else
            _contactButtonModel.alpha = 0.0f;
        
        if (self.frame.size.width > FLT_EPSILON)
        {
            [_contentModel setNeedsSubmodelContentsUpdate];
            [self layoutForContainerSize:self.frame.size];
            
            for (TGModernViewModel *model in self.submodels)
                [model _offsetBoundViews:_boundOffset];
        }
    }
}

- (void)updateEditingState:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage animationDelay:(NSTimeInterval)animationDelay
{
    bool editing = _context.editing;
    if (editing != _editing)
    {
        [super updateEditingState:container viewStorage:viewStorage animationDelay:animationDelay];
        
        _backgroundModel.viewUserInteractionDisabled = _editing;
    }
}

- (void)_maybeRestructureStateModels:(TGModernViewStorage *)viewStorage
{
    if (!_incoming && [_contentModel boundView] == nil && !_incomingAppearance)
    {
        if (_deliveryState == TGMessageDeliveryStateDelivered)
        {
            if (!_checkFirstEmbeddedInContent)
            {
                if ([self.submodels containsObject:_checkFirstModel])
                {
                    _checkFirstEmbeddedInContent = true;
                    
                    [self removeSubmodel:_checkFirstModel viewStorage:viewStorage];
                    _checkFirstModel.frame = CGRectOffset(_checkFirstModel.frame, -_contentModel.frame.origin.x, -_contentModel.frame.origin.y);
                    [_contentModel addSubmodel:_checkFirstModel];
                }
            }
            
            if (_read && !_checkSecondEmbeddedInContent)
            {
                if ([self.submodels containsObject:_checkSecondModel])
                {
                    _checkSecondEmbeddedInContent = true;
                    
                    [self removeSubmodel:_checkSecondModel viewStorage:viewStorage];
                    _checkSecondModel.frame = CGRectOffset(_checkSecondModel.frame, -_contentModel.frame.origin.x, -_contentModel.frame.origin.y);
                    [_contentModel addSubmodel:_checkSecondModel];
                }
            }
        }
    }
}

- (void)bindSpecialViewsToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage atItemPosition:(CGPoint)itemPosition
{
    [super bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:itemPosition];
    
    _boundOffset = CGSizeMake(itemPosition.x, itemPosition.y);
    
    [_backgroundModel bindViewToContainer:container viewStorage:viewStorage];
    [_backgroundModel boundView].frame = CGRectOffset([_backgroundModel boundView].frame, itemPosition.x, itemPosition.y);
    
    [_contactAvatarModel bindViewToContainer:container viewStorage:viewStorage];
    [_contactAvatarModel boundView].frame = CGRectOffset([_contactAvatarModel boundView].frame, itemPosition.x, itemPosition.y);
    
    [_replyHeaderModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x + _contentModel.frame.origin.x + _replyHeaderModel.frame.origin.x, itemPosition.y + _contentModel.frame.origin.y + _replyHeaderModel.frame.origin.y)];
    
    [_replyButtonsModel bindSpecialViewsToContainer:container viewStorage:viewStorage atItemPosition:CGPointMake(itemPosition.x, itemPosition.y)];
    
    [self subscribeToCallbackButtonInProgress];
}

- (void)subscribeToCallbackButtonInProgress {
    if (_replyButtonsModel != nil) {
        __weak TGContactMessageViewModel *weakSelf = self;
        [_callbackButtonInProgressDisposable setDisposable:[[[_context callbackInProgress] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *next) {
            __strong TGContactMessageViewModel *strongSelf = weakSelf;
            if (strongSelf != nil) {
                if (next != nil) {
                    if ([next[@"mid"] intValue] == strongSelf->_mid) {
                        [strongSelf->_replyButtonsModel setButtonIndexInProgress:[next[@"buttonIndex"] intValue]];
                    } else {
                        [strongSelf->_replyButtonsModel setButtonIndexInProgress:NSNotFound];
                    }
                } else {
                    [strongSelf->_replyButtonsModel setButtonIndexInProgress:NSNotFound];
                }
            }
        }]];
    }
}

- (void)bindViewToContainer:(UIView *)container viewStorage:(TGModernViewStorage *)viewStorage
{
    _boundOffset = CGSizeZero;
    
    [self _maybeRestructureStateModels:viewStorage];
    
    [self updateEditingState:nil viewStorage:nil animationDelay:-1.0];
    
    [super bindViewToContainer:container viewStorage:viewStorage];
    
    [_replyHeaderModel bindSpecialViewsToContainer:_contentModel.boundView viewStorage:viewStorage atItemPosition:CGPointMake(_replyHeaderModel.frame.origin.x, _replyHeaderModel.frame.origin.y)];
    
    _boundDoubleTapRecognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(messageDoubleTapGesture:)];
    _boundDoubleTapRecognizer.delegate = self;
    
    UIView *backgroundView = [_backgroundModel boundView];
    [backgroundView addGestureRecognizer:_boundDoubleTapRecognizer];
    
    if (_unsentButtonModel != nil)
    {
        _unsentButtonTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unsentButtonTapGesture:)];
        [[_unsentButtonModel boundView] addGestureRecognizer:_unsentButtonTapRecognizer];
    }
    
    [(UIButton *)[_contactButtonModel boundView] addTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    [self subscribeToCallbackButtonInProgress];
}

- (void)unbindView:(TGModernViewStorage *)viewStorage
{
    UIView *backgroundView = [_backgroundModel boundView];
    [backgroundView removeGestureRecognizer:_boundDoubleTapRecognizer];
    _boundDoubleTapRecognizer.delegate = nil;
    _boundDoubleTapRecognizer = nil;
    
    if (_unsentButtonModel != nil)
    {
        [[_unsentButtonModel boundView] removeGestureRecognizer:_unsentButtonTapRecognizer];
        _unsentButtonTapRecognizer = nil;
    }
    
    [(UIButton *)[_contactButtonModel boundView] removeTarget:self action:@selector(actionButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    [super unbindView:viewStorage];
    
    [_callbackButtonInProgressDisposable setDisposable:nil];
}

- (void)relativeBoundsUpdated:(CGRect)bounds
{
    [super relativeBoundsUpdated:bounds];
    
    [_contentModel updateSubmodelContentsForVisibleRect:CGRectOffset(bounds, -_contentModel.frame.origin.x, -_contentModel.frame.origin.y)];
}

- (CGRect)effectiveContentFrame
{
    return _backgroundModel.frame;
}

- (void)messageDoubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateBegan)
    {
        if (recognizer.state == UIGestureRecognizerStateRecognized)
        {
            CGPoint point = [recognizer locationInView:[_contentModel boundView]];
            
            if (recognizer.longTapped)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            else if (recognizer.doubleTapped)
                [_context.companionHandle requestAction:@"messageSelectionRequested" options:@{@"mid": @(_mid), @"peerId": @(_authorPeerId)}];
            else if (_forwardedHeaderModel && CGRectContainsPoint(_forwardedHeaderModel.frame, point)) {
                if (_viaUser != nil && [_forwardedHeaderModel linkAtPoint:CGPointMake(point.x - _forwardedHeaderModel.frame.origin.x, point.y - _forwardedHeaderModel.frame.origin.y) regionData:NULL]) {
                    [_context.companionHandle requestAction:@"useContextBot" options:@{@"uid": @((int32_t)_viaUser.uid), @"username": _viaUser.userName == nil ? @"" : _viaUser.userName}];
                } else {
                    if (TGPeerIdIsChannel(_forwardedPeerId)) {
                        [_context.companionHandle requestAction:@"peerAvatarTapped" options:@{@"peerId": @(_forwardedPeerId), @"messageId": @(_forwardedMessageId)}];
                    } else {
                        [_context.companionHandle requestAction:@"userAvatarTapped" options:@{@"uid": @((int32_t)_forwardedPeerId)}];
                    }
                }
            }
            else if (_replyHeaderModel && CGRectContainsPoint(_replyHeaderModel.frame, point))
                [_context.companionHandle requestAction:@"navigateToMessage" options:@{@"mid": @(_replyMessageId), @"sourceMid": @(_mid)}];
            else if (CGRectContainsPoint(CGRectOffset(CGRectUnion(_contactAvatarModel.frame, CGRectOffset(CGRectUnion(_contactNameModel.frame, _contactTextModel.frame), _contentModel.frame.origin.x, _contentModel.frame.origin.y)), -_backgroundModel.frame.origin.x, -_backgroundModel.frame.origin.y), point))
            {
                [_context.companionHandle requestAction:@"openVCard" options:@{@"contact": _contact}];
            }
        }
    }
}

- (void)unsentButtonTapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [_context.companionHandle requestAction:@"showUnsentMessageMenu" options:@{@"mid": @(_mid)}];
    }
}

- (void)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer didBeginAtPoint:(CGPoint)__unused point
{
}

- (void)gestureRecognizerDidFail:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
}

- (bool)gestureRecognizerShouldHandleLongTap:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    return true;
}

- (int)gestureRecognizer:(TGDoubleTapGestureRecognizer *)__unused recognizer shouldFailTap:(CGPoint)point
{
    if ((_forwardedHeaderModel && CGRectContainsPoint(_forwardedHeaderModel.frame, point)) || (_replyHeaderModel && CGRectContainsPoint(_replyHeaderModel.frame, point)) || CGRectContainsPoint(CGRectOffset(CGRectUnion(_contactAvatarModel.frame, CGRectOffset(CGRectUnion(_contactNameModel.frame, _contactTextModel.frame), _contentModel.frame.origin.x, _contentModel.frame.origin.y)), -_backgroundModel.frame.origin.x, -_backgroundModel.frame.origin.y), point))
    {
        return 3;
    }
    return false;
}

- (void)doubleTapGestureRecognizerSingleTapped:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
}

- (void)actionButtonPressed
{
    [_context.companionHandle requestAction:@"showContactMessageMenu" options:@{@"contact": _contact, @"addMode": @(true)}];
}

- (void)layoutForContainerSize:(CGSize)containerSize
{
    bool isPost = _authorPeer != nil && [_authorPeer isKindOfClass:[TGConversation class]];
    
    TGMessageViewModelLayoutConstants const *layoutConstants = TGGetMessageViewModelLayoutConstants();
    
    bool isRTL = TGIsRTL();
    
    CGFloat topSpacing = (_collapseFlags & TGModernConversationItemCollapseTop) ? layoutConstants->topInsetCollapsed : layoutConstants->topInset;
    CGFloat bottomSpacing = (_collapseFlags & TGModernConversationItemCollapseBottom) ? layoutConstants->bottomInsetCollapsed : layoutConstants->bottomInset;
    
    if (isPost) {
        topSpacing = layoutConstants->topPostInset;
        bottomSpacing = layoutConstants->bottomPostInset;
    }
    
    bool updateContents = false;
    
    CGSize contentContainerSize = CGSizeMake(320.0f, CGFLOAT_MAX);
    
    bool hasSignature = false;
    if (_authorSignature.length != 0) {
        hasSignature = true;
        if ([_authorSignatureModel layoutNeedsUpdatingForContainerSize:CGSizeMake(contentContainerSize.width - 80.0f, CGFLOAT_MAX)]) {
            updateContents = true;
            [_authorSignatureModel layoutForContainerSize:CGSizeMake(contentContainerSize.width - 80.0f, CGFLOAT_MAX)];
        }
    } else {
        _authorSignatureModel.frame = CGRectZero;
    }
    
    CGSize headerSize = CGSizeZero;
    if (_authorNameModel != nil)
    {
        if (_authorNameModel.frame.size.width < FLT_EPSILON)
            [_authorNameModel layoutForContainerSize:CGSizeMake(320.0f - 80.0f, 0.0f)];
        
        CGRect authorModelFrame = _authorNameModel.frame;
        authorModelFrame.origin = CGPointMake(1.0f, 1.0f);
        _authorNameModel.frame = authorModelFrame;
        
        headerSize = CGSizeMake(_authorNameModel.frame.size.width, _authorNameModel.frame.size.height);
    }
    
    if (hasSignature) {
        headerSize.width = MAX(_authorSignatureModel.frame.size.width + 100.0f, headerSize.width);
    }
    
    if (_forwardedHeaderModel != nil)
    {
        [_forwardedHeaderModel layoutForContainerSize:CGSizeMake(containerSize.width - 80.0f - (_hasAvatar ? 38.0f : 0.0f), containerSize.height)];
        CGRect forwardedHeaderFrame = _forwardedHeaderModel.frame;
        forwardedHeaderFrame.origin = CGPointMake(1.0f, headerSize.height + 1.0f);
        _forwardedHeaderModel.frame = forwardedHeaderFrame;
        headerSize.height += forwardedHeaderFrame.size.height;
        headerSize.width = MAX(headerSize.width, forwardedHeaderFrame.size.width);
    }
    
    if (_replyHeaderModel != nil)
    {
        bool updateContent = false;
        [_replyHeaderModel layoutForContainerSize:CGSizeMake(containerSize.width - 80.0f - (_hasAvatar ? 38.0f : 0.0f), containerSize.height) updateContent:&updateContent];
        if (updateContent)
            [_contentModel setNeedsSubmodelContentsUpdate];
        CGRect replyHeaderFrame = _replyHeaderModel.frame;
        replyHeaderFrame.origin = CGPointMake(1.0f, headerSize.height + 2.0f);
        _replyHeaderModel.frame = replyHeaderFrame;
        
        headerSize.height += replyHeaderFrame.size.height + 1.0f;
        headerSize.width = MAX(headerSize.width, replyHeaderFrame.size.width);
    }
    
    CGFloat avatarOffset = 0.0f;
    if (_hasAvatar)
        avatarOffset = 38.0f;
    
    CGFloat unsentOffset = 0.0f;
    if (!_incomingAppearance && _deliveryState == TGMessageDeliveryStateFailed)
        unsentOffset = 29.0f;
    
    CGRect contactNameFrame = _contactNameModel.frame;
    contactNameFrame.origin = CGPointMake(44.0f, headerSize.height + 4.0f);
    _contactNameModel.frame = contactNameFrame;
    
    [_contactTextModel layoutForContainerSize:CGSizeMake(180.0f, CGFLOAT_MAX)];
    CGRect contactPhoneFrame = _contactTextModel.frame;
    contactPhoneFrame.origin = CGPointMake(contactNameFrame.origin.x, CGRectGetMaxY(contactNameFrame) + 3.0f);
    _contactTextModel.frame = contactPhoneFrame;
    
    CGSize textSize = CGSizeMake(_contactNameModel.frame.origin.x + MAX(_contactNameModel.frame.size.width, _contactTextModel.frame.size.width) + 10.0f, contactPhoneFrame.origin.y + contactPhoneFrame.size.height - contactNameFrame.origin.y);
    
    CGFloat contentWidth = MAX(150.0f, MAX(headerSize.width, textSize.width) + 2.0f + (_incomingAppearance ? 0.0f : 5.0f));
    CGFloat backgroundWidth = MAX(170.0f, MAX(headerSize.width, textSize.width) + 25.0f);
    if (!_contactAdded)
        backgroundWidth += 44;
    
    CGFloat backgroundHeight = headerSize.height + textSize.height + 30.0f;
    backgroundHeight += 41.0f;
    
    CGRect backgroundFrame = CGRectMake(_incomingAppearance ? (avatarOffset + layoutConstants->leftInset) : (containerSize.width - backgroundWidth - layoutConstants->rightInset - unsentOffset), topSpacing, backgroundWidth, MAX((_hasAvatar ? 44.0f : 30.0f), backgroundHeight));
    if (_incomingAppearance && _editing)
        backgroundFrame.origin.x += 42.0f;
    
    if (!_editing && fabs(_replyPanOffset) > FLT_EPSILON)
        backgroundFrame.origin.x += _replyPanOffset;
    
    _backgroundModel.frame = backgroundFrame;
    
    CGRect contentFrame = CGRectMake(backgroundFrame.origin.x + (_incomingAppearance ? 14 : 8), topSpacing + 2.0f, contentWidth, MAX(headerSize.height + textSize.height + 25.0f, _hasAvatar ? 30.0f : 14.0f));
    if (!_contactAdded)
        contentFrame.size.width += 44.0f;
    contentFrame.size.height += 41.0f;
    _contentModel.frame = contentFrame;
    
    if (_authorNameModel != nil)
    {
        CGRect authorModelFrame = _authorNameModel.frame;
        authorModelFrame.origin.x = isRTL ? (_contentModel.frame.size.width - authorModelFrame.size.width - 1.0f - (_incomingAppearance ? 0.0f : 4.0f)) : 1.0f;
        _authorNameModel.frame = authorModelFrame;
    }
    
    if (_forwardedHeaderModel != nil)
    {
        CGRect forwardedHeaderFrame = _forwardedHeaderModel.frame;
        forwardedHeaderFrame.origin.x = isRTL ? (_contentModel.frame.size.width - forwardedHeaderFrame.size.width - 1.0f - (_incomingAppearance ? 0.0f : 4.0f)) : 1.0f;
        _forwardedHeaderModel.frame = forwardedHeaderFrame;
    }
    
    if (_replyHeaderModel != nil)
    {
        CGRect replyHeaderFrame = _replyHeaderModel.frame;
        replyHeaderFrame.origin.x = isRTL ? (_contentModel.frame.size.width - replyHeaderFrame.size.width - 1.0f) : 1.0f;
        _replyHeaderModel.frame = replyHeaderFrame;
    }
    
    if (isRTL)
    {
        CGRect contactNameFrame = _contactNameModel.frame;
        contactNameFrame.origin.x = _contentModel.frame.size.width - 1.0f - contactNameFrame.size.width - (_incomingAppearance ? 0.0f : 4.0f);
        _contactNameModel.frame = contactNameFrame;
        
        CGRect contactPhoneFrame = _contactTextModel.frame;
        contactPhoneFrame.origin.x = _contentModel.frame.size.width - 1.0f - contactPhoneFrame.size.width - (_incomingAppearance ? 0.0f : 4.0f);
        _contactTextModel.frame = contactPhoneFrame;
    }
    
    _contactAvatarModel.frame = CGRectMake(_contentModel.frame.origin.x - 1.0f, headerSize.height + 9.0f, 40.0f, 40.0f);
    
    if (!_contactAdded)
    {
        _contactButtonModel.frame = CGRectMake(CGRectGetMaxX(_contentModel.frame) - 44.0f + 1.0f + (_incomingAppearance ? 5.0f : 0.0f), CGRectGetMinY(_contentModel.frame) + CGRectGetMinY(_contactNameModel.frame) - 5.0f, 46.0f, 54.0f);
    }
    
    if (_actionButtonModel != nil) {
        CGFloat instantOffset = CGRectGetMaxY(_contactTextModel.frame) + 8.0f;
        CGFloat instantPageButtonWidth = _backgroundModel.frame.size.width - 26.0f;
        _actionButtonModel.frame = CGRectMake(_contentModel.frame.origin.x + 2.0f, instantOffset + 8.0f, instantPageButtonWidth, 33.0f);
    }
    
    _dateModel.frame = CGRectMake(_contentModel.frame.size.width - (_incomingAppearance ? (3 + TGRetinaPixel) : 20.0f) - _dateModel.frame.size.width, _contentModel.frame.size.height - 18.0f - (TGIsLocaleArabic() ? 1.0f : 0.0f), _dateModel.frame.size.width, _dateModel.frame.size.height);
    
    CGFloat signatureSize = (hasSignature ? (_authorSignatureModel.frame.size.width + 8.0f) : 0.0f);
    
    if (_progressModel != nil) {
        if (_incomingAppearance) {
            _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - _dateModel.frame.size.width - 27.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
        } else {
            _progressModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - 23.0f - layoutConstants->rightInset - unsentOffset + (TGIsPad() ? 12.0f : 0.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f, 15, 15);
        }
    }
    
    if (_authorSignature.length != 0) {
        _authorSignatureModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - _dateModel.frame.size.width - 22.0f - (_incomingAppearance ? 0.0f : 14.0f) - _authorSignatureModel.frame.size.width - 12.0f - (TGIsPad() ? 12.0f : 0.0f), _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f - 7.0f - (TGIsPad() ? 1.0f : 0.0f), _authorSignatureModel.frame.size.width, _authorSignatureModel.frame.size.height);
    } else {
        _authorSignatureModel.frame = CGRectZero;
    }
    
    if (_messageViewsModel != nil) {
        _messageViewsModel.frame = CGRectMake(CGRectGetMaxX(_backgroundModel.frame) - _dateModel.frame.size.width - 22.0f - (_incomingAppearance ? 0.0f : 14.0f) - signatureSize, _contentModel.frame.origin.y + _contentModel.frame.size.height - 17 + 1.0f + TGRetinaPixel, 1.0f, 1.0f);
    }
    
    CGPoint stateOffset = _contentModel.frame.origin;
    if (_checkFirstModel != nil)
        _checkFirstModel.frame = CGRectMake((_checkFirstEmbeddedInContent ? 0.0f : stateOffset.x) + _contentModel.frame.size.width - 17, (_checkFirstEmbeddedInContent ? 0.0f : stateOffset.y) + _contentModel.frame.size.height - 13, 12, 11);
    
    if (_checkSecondModel != nil)
        _checkSecondModel.frame = CGRectMake((_checkSecondEmbeddedInContent ? 0.0f : stateOffset.x) + _contentModel.frame.size.width - 13, (_checkSecondEmbeddedInContent ? 0.0f : stateOffset.y) + _contentModel.frame.size.height - 13, 12, 11);
    
    if (_unsentButtonModel != nil)
    {
        _unsentButtonModel.frame = CGRectMake(containerSize.width - _unsentButtonModel.frame.size.width - 9, backgroundFrame.size.height + topSpacing + bottomSpacing - _unsentButtonModel.frame.size.height - ((_collapseFlags & TGModernConversationItemCollapseBottom) ? 5 : 6), _unsentButtonModel.frame.size.width, _unsentButtonModel.frame.size.height);
    }
    
    CGFloat replyButtonsHeight = 0.0f;
    if (_replyButtonsModel != nil) {
        [_replyButtonsModel layoutForContainerSize:CGSizeMake(backgroundFrame.size.width + 4.0f, containerSize.height)];
        _replyButtonsModel.frame = CGRectMake(_incomingAppearance ? backgroundFrame.origin.x : (CGRectGetMaxX(backgroundFrame) - _replyButtonsModel.frame.size.width), CGRectGetMaxY(backgroundFrame), _replyButtonsModel.frame.size.width, _replyButtonsModel.frame.size.height);
        replyButtonsHeight = _replyButtonsModel.frame.size.height;
        self.avatarOffset = replyButtonsHeight;
    }
    
    self.frame = CGRectMake(0, 0, containerSize.width, backgroundFrame.size.height + topSpacing + bottomSpacing + replyButtonsHeight);
    
    [_contentModel updateSubmodelContentsIfNeeded];
    
    [super layoutForContainerSize:containerSize];
}

- (void)setCollapseFlags:(int)collapseFlags
{
    if (_collapseFlags != collapseFlags)
    {
        _collapseFlags = collapseFlags;
        if ([_authorPeer isKindOfClass:[TGConversation class]]) {
            [_backgroundModel setPartialMode:false];
        } else {
            [_backgroundModel setPartialMode:collapseFlags & TGModernConversationItemCollapseBottom];
        }
    }
}

@end
