#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CodePad16ScintillaView : NSView
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSString *lexerName;
@property(nonatomic, copy) NSArray<NSString *> *keywordSets;
@property(nonatomic, copy, nullable) void (^onChange)(NSString *text, NSInteger line, NSInteger column, BOOL modified);
- (void)selectRange:(NSRange)range;
- (NSRange)selection;
- (void)find:(NSString *)query backwards:(BOOL)backwards;
@property(nonatomic, readonly) NSInteger caretPosition;
@property(nonatomic, readonly) NSInteger firstVisibleLine;
@property(nonatomic, readonly) NSString *selectedText;
- (void)setCaretPosition:(NSInteger)position;
- (void)setFirstVisibleLine:(NSInteger)line;
@end

NS_ASSUME_NONNULL_END
