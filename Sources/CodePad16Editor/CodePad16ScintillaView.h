#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CodePad16ScintillaView : NSView
@property(nonatomic, copy) NSString *text;
@property(nonatomic, copy) NSString *lexerName;
@property(nonatomic, copy) NSArray<NSString *> *keywordSets;
@property(nonatomic) BOOL wordWrap;
@property(nonatomic) BOOL matchCase;
/// Called for edits and cursor/status changes. `edited` is true only when text
/// was inserted or deleted; the buffer itself is pulled lazily through `text`.
@property(nonatomic, copy, nullable) void (^onChange)(BOOL edited, NSInteger line, NSInteger column, BOOL modified, NSInteger lineCount);
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
/// Whether the buffer changed since it was last copied into the document model.
/// Reading the whole buffer on every edit is expensive for large files, so the
/// Swift layer only copies it when the view state is captured or the file is saved.
@property(nonatomic, readonly) BOOL textNeedsSync;
/// Clears `textNeedsSync` after the buffer has been copied into the model.
- (void)clearTextNeedsSync;
/// Marks the current buffer as the saved state, so edits made before a save no
/// longer leave the document flagged as modified.
- (void)markSaved;
@property(nonatomic, readonly) NSInteger lineCount;
@property(nonatomic, readonly) NSInteger caretPosition;
@property(nonatomic, readonly) NSInteger firstVisibleLine;
@property(nonatomic, readonly) NSString *selectedText;
- (void)setCaretPosition:(NSInteger)position;
- (void)setFirstVisibleLine:(NSInteger)line;
@end

NS_ASSUME_NONNULL_END
