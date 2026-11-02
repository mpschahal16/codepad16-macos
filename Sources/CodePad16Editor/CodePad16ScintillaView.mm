#import "CodePad16ScintillaView.h"
#import "ScintillaView.h"
#import "ScintillaTypes.h"
#import "Scintilla.h"
#import "ScintillaMessages.h"
#import "ScintillaStructures.h"
#include "ILexer.h"
#include "Lexilla.h"

@interface CodePad16ScintillaView () <ScintillaNotificationProtocol>
@property(nonatomic, strong) ScintillaView *editor;
@property(nonatomic, copy) NSString *configuredLexer;
@end

@implementation CodePad16ScintillaView

@synthesize wordWrap = _wordWrap;

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _lexerName = @"";
        _keywordSets = @[];
        _editor = [[ScintillaView alloc] initWithFrame:self.bounds];
        _editor.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        _editor.delegate = self;
        [self addSubview:_editor];
        [self configureEditor];
    }
    return self;
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    self.editor.frame = self.bounds;
}

- (void)setText:(NSString *)text {
    if (![self.editor.string isEqualToString:text]) {
        [self.editor setString:text ?: @""];
        [self.editor message:SCI_EMPTYUNDOBUFFER];
        [self.editor message:SCI_SETSAVEPOINT];
    }
}

- (NSString *)text { return self.editor.string ?: @""; }

- (void)setLexerName:(NSString *)lexerName {
    _lexerName = [lexerName copy];
    [self configureLexer];
}

- (void)setKeywordSets:(NSArray<NSString *> *)keywordSets {
    _keywordSets = [keywordSets copy];
    [self configureKeywords];
}

/// Scintilla wraps at word boundaries to the view width. While wrapping is on
/// it hides the horizontal scroll bar, so long lines no longer need one.
- (void)setWordWrap:(BOOL)wordWrap {
    if (_wordWrap == wordWrap) return;
    _wordWrap = wordWrap;
    [self.editor message:SCI_SETWRAPMODE wParam:(wordWrap ? SC_WRAP_WORD : SC_WRAP_NONE) lParam:0];
}

- (void)configureEditor {
    [self.editor setEditable:YES];
    [self.editor message:SCI_SETUNDOCOLLECTION wParam:1];
    [self.editor message:SCI_SETMARGINTYPEN wParam:0 lParam:SC_MARGIN_NUMBER];
    [self.editor message:SCI_SETMARGINWIDTHN wParam:0 lParam:46];
    [self.editor message:SCI_SETMARGINSENSITIVEN wParam:0 lParam:0];
    [self.editor message:SCI_SETCARETLINEVISIBLE wParam:1];
    [self applyTheme];
}

- (BOOL)usesDarkAppearance {
    NSAppearanceName match = [self.effectiveAppearance bestMatchFromAppearancesWithNames:@[
        NSAppearanceNameAqua, NSAppearanceNameDarkAqua
    ]];
    return [match isEqualToString:NSAppearanceNameDarkAqua];
}

/// Applies the light or dark editor palette. Called at setup and whenever the
/// effective appearance changes (system switch or an explicit app setting).
- (void)applyTheme {
    if (!self.editor) return;
    BOOL dark = [self usesDarkAppearance];

    int background = dark ? 0x1e1e1e : 0xffffff;
    int foreground = dark ? 0xd4d4d4 : 0x202020;
    int lineNumberForeground = dark ? 0x858585 : 0x777777;
    int lineNumberBackground = dark ? 0x252526 : 0xf4f4f4;
    int caretLineBackground = dark ? 0x2a2d2e : 0xf7f7f7;
    int caretForeground = dark ? 0xe6e6e6 : 0x202020;
    int selectionBackground = dark ? 0x264f78 : 0xb4d7ff;
    int selectionForeground = dark ? 0xffffff : 0x000000;

    [self.editor message:SCI_STYLESETFONT wParam:STYLE_DEFAULT lParam:(sptr_t)"Menlo"];
    [self.editor message:SCI_STYLESETSIZE wParam:STYLE_DEFAULT lParam:14];
    [self.editor message:SCI_STYLESETFORE wParam:STYLE_DEFAULT lParam:foreground];
    [self.editor message:SCI_STYLESETBACK wParam:STYLE_DEFAULT lParam:background];
    [self.editor message:SCI_STYLECLEARALL];

    [self.editor message:SCI_STYLESETFORE wParam:STYLE_LINENUMBER lParam:lineNumberForeground];
    [self.editor message:SCI_STYLESETBACK wParam:STYLE_LINENUMBER lParam:lineNumberBackground];
    [self.editor message:SCI_STYLESETFONT wParam:STYLE_LINENUMBER lParam:(sptr_t)"Menlo"];
    [self.editor message:SCI_STYLESETSIZE wParam:STYLE_LINENUMBER lParam:11];
    [self.editor message:SCI_SETMARGINBACKN wParam:0 lParam:lineNumberBackground];

    [self.editor message:SCI_SETCARETLINEBACK wParam:caretLineBackground];
    [self.editor message:SCI_SETCARETFORE wParam:caretForeground];
    [self.editor message:SCI_SETSELBACK wParam:1 lParam:selectionBackground];
    [self.editor message:SCI_SETSELFORE wParam:1 lParam:selectionForeground];

    [self configureColors];
    [self.editor message:SCI_COLOURISE wParam:0 lParam:-1];
    [self.editor setNeedsDisplay:YES];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self applyTheme];
}

- (void)configureLexer {
    if (!self.editor || [self.configuredLexer isEqualToString:self.lexerName]) return;
    self.configuredLexer = self.lexerName;
    const char *name = self.lexerName.UTF8String;
    Scintilla::ILexer5 *lexer = (self.lexerName.length > 0) ? CreateLexer(name) : nullptr;
    [self.editor message:SCI_SETILEXER wParam:0 lParam:(sptr_t)lexer];
    [self configureKeywords];
    [self configureColors];
    [self.editor message:SCI_COLOURISE wParam:0 lParam:-1];
}

- (void)configureKeywords {
    for (NSUInteger index = 0; index < self.keywordSets.count && index < 9; index++) {
        const char *words = self.keywordSets[index].UTF8String;
        [self.editor message:SCI_SETKEYWORDS wParam:index lParam:(sptr_t)words];
    }
    [self.editor message:SCI_COLOURISE wParam:0 lParam:-1];
}

- (void)configureColors {
    BOOL dark = [self usesDarkAppearance];
    int commentColor = dark ? 0x6a9955 : 0x538252;
    int numberColor = dark ? 0xb5cea8 : 0x986801;
    int stringColor = dark ? 0xce9178 : 0x9a3e72;
    int keywordColor = dark ? 0x569cd6 : 0x0000cc;
    int operatorColor = dark ? 0xd4d4d4 : 0x5e5e5e;
    int propertyColor = dark ? 0x9cdcfe : 0x8459a6;

    NSArray<NSNumber *> *comments = @[];
    NSArray<NSNumber *> *numbers = @[];
    NSArray<NSNumber *> *strings = @[];
    NSArray<NSNumber *> *keywords = @[];
    NSArray<NSNumber *> *operators = @[];
    NSArray<NSNumber *> *properties = @[];
    if ([self.lexerName isEqualToString:@"cpp"]) {
        comments = @[@1, @2, @3, @15]; numbers = @[@4]; strings = @[@6, @7, @20, @21, @22];
        keywords = @[@5, @16]; operators = @[@10];
    } else if ([self.lexerName isEqualToString:@"python"]) {
        comments = @[@1, @12]; numbers = @[@2]; strings = @[@3, @4, @6, @7, @13, @16, @17, @18, @19];
        keywords = @[@5, @14]; operators = @[@10]; properties = @[@8, @9, @15];
    } else if ([self.lexerName isEqualToString:@"hypertext"]) {
        comments = @[@9, @20, @29]; numbers = @[@5, @45, @60]; strings = @[@6, @7, @48, @49, @63, @64, @53, @68];
        keywords = @[@46, @47, @61, @62]; operators = @[@11, @50, @65]; properties = @[@1, @3, @10, @12, @13, @19];
    } else if ([self.lexerName isEqualToString:@"css"]) {
        comments = @[@9]; numbers = @[]; strings = @[@13, @14]; keywords = @[@11, @12, @23];
        operators = @[@5]; properties = @[@1, @2, @3, @6, @8, @10, @15, @16, @17, @18, @19, @20, @21, @22];
    } else if ([self.lexerName isEqualToString:@"json"]) {
        comments = @[@6, @7]; numbers = @[@1]; strings = @[@2, @3, @5, @9, @10];
        keywords = @[@11, @12]; operators = @[@8]; properties = @[@4];
    } else if ([self.lexerName isEqualToString:@"xml"]) {
        comments = @[@9, @20, @29]; numbers = @[@5]; strings = @[@6, @7, @24, @25];
        keywords = @[]; operators = @[@11, @18]; properties = @[@1, @2, @3, @4, @10, @12, @13, @17, @19, @22, @23];
    } else if ([self.lexerName isEqualToString:@"sql"]) {
        comments = @[@1, @2, @3, @13, @15, @17, @18]; numbers = @[@4]; strings = @[@6, @7, @23];
        keywords = @[@5, @16]; operators = @[@10, @24]; properties = @[@8, @9, @11, @19, @20, @21, @22];
    }
    for (NSNumber *style in comments) [self.editor message:SCI_STYLESETFORE wParam:style.intValue lParam:commentColor];
    for (NSNumber *style in numbers) [self.editor message:SCI_STYLESETFORE wParam:style.intValue lParam:numberColor];
    for (NSNumber *style in strings) [self.editor message:SCI_STYLESETFORE wParam:style.intValue lParam:stringColor];
    for (NSNumber *style in keywords) {
        [self.editor message:SCI_STYLESETFORE wParam:style.intValue lParam:keywordColor];
        [self.editor message:SCI_STYLESETBOLD wParam:style.intValue lParam:1];
    }
    for (NSNumber *style in operators) [self.editor message:SCI_STYLESETFORE wParam:style.intValue lParam:operatorColor];
    for (NSNumber *style in properties) [self.editor message:SCI_STYLESETFORE wParam:style.intValue lParam:propertyColor];
}

- (void)notification:(SCNotification *)notification {
    if (!self.onChange) return;

    int code = notification->nmhdr.code;
    BOOL edited = NO;
    if (code == SCN_MODIFIED) {
        // Style, fold, and other bookkeeping notifications also arrive here;
        // only copy the buffer when text was actually inserted or deleted.
        int textChange = SC_MOD_INSERTTEXT | SC_MOD_DELETETEXT;
        if ((notification->modificationType & textChange) == 0) return;
        edited = YES;
    } else if (code != SCN_UPDATEUI && code != SCN_SAVEPOINTREACHED && code != SCN_SAVEPOINTLEFT) {
        return;
    }

    NSInteger position = (NSInteger)[self.editor message:SCI_GETCURRENTPOS];
    NSInteger line = (NSInteger)[self.editor message:SCI_LINEFROMPOSITION wParam:position] + 1;
    NSInteger column = (NSInteger)[self.editor message:SCI_GETCOLUMN wParam:position] + 1;
    BOOL modified = [self.editor message:SCI_GETMODIFY] != 0;
    NSInteger lineCount = (NSInteger)[self.editor message:SCI_GETLINECOUNT];
    // Passing nil for cursor-only updates avoids copying the whole document
    // on every caret move, selection change, and scroll.
    self.onChange(edited ? self.text : nil, line, column, modified, lineCount);
}

- (NSRange)selection {
    NSInteger start = (NSInteger)[self.editor message:SCI_GETSELECTIONSTART];
    NSInteger end = (NSInteger)[self.editor message:SCI_GETSELECTIONEND];
    return NSMakeRange((NSUInteger)start, (NSUInteger)MAX(0, end - start));
}

/// Returns the 1-based index of the next match from the selection in `location`
/// (0 when the selection is past the last match) and the total in `length`.
- (NSRange)matchInfo:(NSString *)query {
    if (!query.length) return NSMakeRange(0, 0);
    NSData *needle = [query dataUsingEncoding:NSUTF8StringEncoding];
    if (!needle.length) return NSMakeRange(0, 0);
    const char *bytes = static_cast<const char *>(needle.bytes);
    const sptr_t needleLength = static_cast<sptr_t>(needle.length);

    [self.editor message:SCI_SETSEARCHFLAGS wParam:SCFIND_MATCHCASE lParam:0];

    const sptr_t selectionStart = [self.editor message:SCI_GETSELECTIONSTART];
    const sptr_t maximum = [self.editor message:SCI_GETLENGTH];
    sptr_t position = 0;
    NSInteger total = 0;
    NSInteger index = 0;
    while (position <= maximum) {
        [self.editor message:SCI_SETTARGETRANGE wParam:position lParam:maximum];
        const sptr_t found = (sptr_t)[self.editor message:SCI_SEARCHINTARGET wParam:needleLength lParam:(sptr_t)bytes];
        if (found < 0) break;
        total += 1;
        if (index == 0 && found >= selectionStart) index = total;
        const sptr_t foundEnd = (sptr_t)[self.editor message:SCI_GETTARGETEND];
        position = (foundEnd > found) ? foundEnd : found + 1;
    }
    return NSMakeRange((NSUInteger)index, (NSUInteger)total);
}

- (void)selectRange:(NSRange)range {
    [self.editor message:SCI_SETSEL wParam:range.location lParam:NSMaxRange(range)];
    [self.editor message:SCI_SCROLLCARET];
    [self.window makeFirstResponder:self.editor.content];
}

- (void)find:(NSString *)query backwards:(BOOL)backwards {
    if (!query.length) return;
    NSData *needle = [query dataUsingEncoding:NSUTF8StringEncoding];
    if (!needle.length) return;
    const char *bytes = static_cast<const char *>(needle.bytes);
    const sptr_t needleLength = static_cast<sptr_t>(needle.length);

    [self.editor message:SCI_SETSEARCHFLAGS wParam:SCFIND_MATCHCASE lParam:0];

    const sptr_t minimum = 0;
    const sptr_t maximum = [self.editor message:SCI_GETLENGTH];
    const sptr_t anchor = backwards
        ? [self.editor message:SCI_GETSELECTIONSTART]
        : [self.editor message:SCI_GETSELECTIONEND];

    // Search beside the current selection first, then wrap around the document,
    // so repeated Find Next / Find Previous moves through all matches.
    // A target range whose end precedes its start searches backwards.
    const sptr_t ranges[2][2] = {
        { anchor, backwards ? minimum : maximum },
        { backwards ? maximum : minimum, backwards ? minimum : maximum },
    };

    sptr_t found = -1;
    sptr_t foundEnd = 0;
    for (int pass = 0; pass < 2 && found < 0; pass++) {
        [self.editor message:SCI_SETTARGETRANGE wParam:ranges[pass][0] lParam:ranges[pass][1]];
        found = (sptr_t)[self.editor message:SCI_SEARCHINTARGET wParam:needleLength lParam:(sptr_t)bytes];
        if (found >= 0) {
            foundEnd = (sptr_t)[self.editor message:SCI_GETTARGETEND];
        }
    }

    if (found < 0) return;
    [self.editor message:SCI_SETSEL wParam:found lParam:foundEnd];
    [self.editor message:SCI_SCROLLCARET];
}

- (NSInteger)caretPosition {
    return (NSInteger)[self.editor message:SCI_GETCURRENTPOS];
}

- (void)setCaretPosition:(NSInteger)position {
    if (position < 0) return;
    [self.editor message:SCI_GOTOPOS wParam:position lParam:0];
}

- (NSInteger)firstVisibleLine {
    return (NSInteger)[self.editor message:SCI_GETFIRSTVISIBLELINE];
}

- (NSString *)selectedText {
    NSInteger start = (NSInteger)[self.editor message:SCI_GETSELECTIONSTART];
    NSInteger end = (NSInteger)[self.editor message:SCI_GETSELECTIONEND];
    if (end <= start) return @"";
    NSUInteger length = (NSUInteger)(end - start);
    NSMutableData *buffer = [NSMutableData dataWithLength:length + 1];
    [self.editor message:SCI_GETSELTEXT wParam:0 lParam:(sptr_t)buffer.mutableBytes];
    NSString *text = [NSString stringWithUTF8String:(const char *)buffer.bytes];
    return text ?: @"";
}

- (void)setFirstVisibleLine:(NSInteger)line {
    if (line < 0) return;
    [self.editor message:SCI_SETFIRSTVISIBLELINE wParam:line lParam:0];
}

@end
