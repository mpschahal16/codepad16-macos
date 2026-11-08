#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CodePad16ScintillaView : NSView
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSString *lexerName;
@property(nonatomic, copy) NSArray<NSString *> *keywordSets;
@property(nonatomic) BOOL wordWrap;
@property(nonatomic) BOOL matchCase;
@property(nonatomic, copy, nullable) void (^onChange)(NSString * _Nullable text, NSInteger line, NSInteger column, BOOL modified, NSInteger lineCount);
/// Called after a double-click in the gutter adds or removes a pointer marker.
@property(nonatomic, copy, nullable) void (^onPointerChange)(NSArray<NSNumber *> *lines);
/// 1-based line numbers that currently show a pointer marker, sorted ascending.
@property(nonatomic, copy) NSArray<NSNumber *> *pointerLines;
/// Toggles the pointer marker on a 1-based line.
- (void)togglePointerAtLine:(NSInteger)line;
- (void)selectRange:(NSRange)range;
- (NSRange)selection;
- (NSRange)matchInfo:(NSString *)query;
- (void)find:(NSString *)query backwards:(BOOL)backwards;
- (BOOL)replace:(NSString *)query with:(NSString *)replacement;
- (NSInteger)replaceAll:(NSString *)query with:(NSString *)replacement;
- (void)goToLine:(NSInteger)line;
@property(nonatomic, readonly) NSInteger lineCount;
@property(nonatomic, readonly) NSInteger caretPosition;
@property(nonatomic, readonly) NSInteger firstVisibleLine;
@property(nonatomic, readonly) NSString *selectedText;
- (void)setCaretPosition:(NSInteger)position;
- (void)setFirstVisibleLine:(NSInteger)line;
@end

NS_ASSUME_NONNULL_END
