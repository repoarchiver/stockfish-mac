//
//  SFMBoardView.m
//  Stockfish
//
//  Created by Daylen Yang on 1/10/14.
//  Copyright (c) 2014 Daylen Yang. All rights reserved.
//

#import "SFMPosition.h"
#import "SFMBoardView.h"
#import "Constants.h"
#import "SFMPieceView.h"
#import "SFMArrowView.h"
#import "SFMMove.h"
#import "NSColor+ColorUtils.h"

@interface SFMBoardView()

#pragma mark - Colors

@property NSColor *boardColor;
@property NSColor *lightSquareColor;
@property NSColor *darkSquareColor;
@property NSColor *fontColor;
@property NSColor *highlightColor;

#pragma mark - State

@property (nonatomic) NSMutableDictionary /* <NSNumber, SFMPieceView> */ *pieceViews;
@property (nonatomic) NSMutableDictionary /* <SFMMove, SFMArrowView> */ *arrowViews;

@property (nonatomic) NSArray /* of NSNumber */ *highlightedSquares;

@property (assign, nonatomic) BOOL isDragging;
@property (nonatomic) SFMSquare fromSquare;
@property (nonatomic) SFMSquare toSquare;

#pragma mark - Metrics

@property (readonly, assign, nonatomic) CGFloat leftInset;
@property (readonly, assign, nonatomic) CGFloat topInset;
@property (readonly, assign, nonatomic) CGFloat squareSideLength;

@end

@implementation SFMBoardView

#pragma mark - Init
- (instancetype)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.wantsLayer = YES;
        _boardIsFlipped = NO;
        
        _boardColor = [NSColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1];
        _lightSquareColor = [NSColor colorWithHex:0xf6fbf8 alpha:1];
        _darkSquareColor = [NSColor colorWithHex:0x8bcea3 alpha:1];
        _fontColor = [NSColor whiteColor];
        _highlightColor = [NSColor colorWithSRGBRed:1 green:1 blue:0 alpha:0.7];
        
        _pieceViews = [[NSMutableDictionary alloc] init];
        _arrowViews = [[NSMutableDictionary alloc] init];
        _highlightedSquares = [[NSMutableArray alloc] init];
    }
    return self;
}

#pragma mark - Setters

- (void)setBoardIsFlipped:(BOOL)boardIsFlipped {
    _boardIsFlipped = boardIsFlipped;
    [self setNeedsDisplay:YES];
    [self resizeSubviewsWithOldSize:NSMakeSize(0, 0)];
}

- (void)setPosition:(SFMPosition *)position {
    _position = position;
    
    [self.pieceViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [obj removeFromSuperview];
    }];
    [self.pieceViews removeAllObjects];
    
    for (SFMSquare s = SQ_A1; s <= SQ_H8; s++) {
        SFMPiece piece = [self.position pieceOnSquare:s];
        if (piece != NO_PIECE && piece != EMPTY) {
            SFMPieceView *view = [[SFMPieceView alloc] init];
            view.piece = piece;
            self.pieceViews[[NSNumber numberWithInteger:s]] = view;
            [self addSubview:view];
        }
    }
    
    [self resizeSubviewsWithOldSize:NSMakeSize(0, 0)];
}

- (void)setArrows:(NSArray *)arrows {
    _arrows = arrows;

    [self.arrowViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [obj removeFromSuperview];
    }];
    [self.arrowViews removeAllObjects];
    
    for (SFMMove *move in _arrows) {
        SFMArrowView *view = [[SFMArrowView alloc] initWithFrame:self.bounds];
        self.arrowViews[move] = view;
        [self addSubview:view];
    }
    
    [self resizeSubviewsWithOldSize:NSMakeSize(0, 0)];
}

#pragma mark - Drawing

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    if (!self.isDragging) {
        [self.pieceViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            SFMSquare s = ((NSNumber *)key).integerValue;
            NSView *view = obj;
            CGPoint coordinate = [self coordinatesForSquare:s
                                                 leftOffset:self.leftInset
                                                  topOffset:self.topInset
                                                 sideLength:self.squareSideLength];
            view.frame = NSMakeRect(coordinate.x, coordinate.y,
                                    self.squareSideLength, self.squareSideLength);
        }];
    }
    [self.arrowViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        SFMMove *move = key;
        SFMArrowView *view = obj;
        view.fromPoint = [self coordinatesForSquare:move.from
                                         leftOffset:self.leftInset + self.squareSideLength / 2
                                          topOffset:self.topInset + self.squareSideLength / 2
                                         sideLength:self.squareSideLength];
        view.toPoint = [self coordinatesForSquare:move.to
                                       leftOffset:self.leftInset + self.squareSideLength / 2
                                        topOffset:self.topInset + self.squareSideLength / 2
                                       sideLength:self.squareSideLength];
        view.squareSideLength = self.squareSideLength;
        [view setNeedsDisplay:YES];
    }];
}

- (void)drawRect:(NSRect)dirtyRect {
    
    // Draw the border
    CGFloat height = self.bounds.size.height;
    CGFloat width = self.bounds.size.width;
    CGFloat boardSideLength = MIN(height, width) - EXTERIOR_BOARD_MARGIN * 2;
    [self.boardColor set];
    CGFloat left = (width - boardSideLength) / 2;
    CGFloat top = (height - boardSideLength) / 2;
    NSRectFill(NSMakeRect(left, top, boardSideLength, boardSideLength));
    
    // Draw 64 squares
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            if ((i + j) % 2 == 0) {
                [self.lightSquareColor set];
            } else {
                [self.darkSquareColor set];
            }
            NSRectFill(NSMakeRect(self.leftInset + i * self.squareSideLength,
                                  self.topInset + j * self.squareSideLength,
                                  self.squareSideLength, self.squareSideLength));
        }
    }
    
    // Draw coordinates
    NSString *str;
    NSMutableParagraphStyle *pStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    [pStyle setAlignment:NSCenterTextAlignment];
    for (int i = 0; i < 8; i++) {
        // Down
        str = [NSString stringWithFormat:@"%d", self.boardIsFlipped ? (i + 1) : (8 - i)];
        [str drawInRect:NSMakeRect(left, self.topInset + self.squareSideLength / 2 - FONT_SIZE / 2
                                   + i * self.squareSideLength, INTERIOR_BOARD_MARGIN,
                                   self.squareSideLength)
         withAttributes:@{NSParagraphStyleAttributeName: pStyle,
                          NSForegroundColorAttributeName: self.fontColor}];
        // Across
        str = [NSString stringWithFormat:@"%c", self.boardIsFlipped ? ('h' - i) : ('a' + i)];
        [str drawInRect:NSMakeRect(self.leftInset + i * self.squareSideLength, self.topInset +
                                   8 * self.squareSideLength, self.squareSideLength,
                                   INTERIOR_BOARD_MARGIN)
         withAttributes:@{NSParagraphStyleAttributeName: pStyle,
                          NSForegroundColorAttributeName: self.fontColor}];
    }
    
    // Draw highlighted squares
    [self.highlightColor set];
    for (NSNumber *num in self.highlightedSquares) {
        SFMSquare square = num.integerValue;
        CGPoint coordinate = [self coordinatesForSquare:square
                                             leftOffset:self.leftInset
                                              topOffset:self.topInset
                                             sideLength:self.squareSideLength];
        [NSBezierPath fillRect:NSMakeRect(coordinate.x, coordinate.y,
                                          self.squareSideLength, self.squareSideLength)];
    }
    
}

#pragma mark - Getters

- (CGFloat)topInset {
    CGFloat height = self.bounds.size.height;
    CGFloat width = self.bounds.size.width;
    CGFloat boardSideLength = MIN(height, width) - EXTERIOR_BOARD_MARGIN * 2;
    
    return (height - boardSideLength) / 2 + INTERIOR_BOARD_MARGIN;
}

- (CGFloat)leftInset {
    CGFloat height = self.bounds.size.height;
    CGFloat width = self.bounds.size.width;
    CGFloat boardSideLength = MIN(height, width) - EXTERIOR_BOARD_MARGIN * 2;
    
    return (width - boardSideLength) / 2 + INTERIOR_BOARD_MARGIN;
}

- (CGFloat)squareSideLength {
    CGFloat height = self.bounds.size.height;
    CGFloat width = self.bounds.size.width;
    CGFloat boardSideLength = MIN(height, width) - EXTERIOR_BOARD_MARGIN * 2;
    
    return (boardSideLength - 2 * INTERIOR_BOARD_MARGIN) / 8;
}

#pragma mark - Conversions

- (CGPoint)coordinatesForSquare:(SFMSquare)sq
                     leftOffset:(CGFloat)left
                      topOffset:(CGFloat)top
                     sideLength:(CGFloat)sideLength
{
    int letter = sq % 8;
    int number = sq / 8;
    CGFloat l, t;
    if (self.boardIsFlipped) {
        l = left + (7 - letter) * sideLength;
        t = top + number * sideLength;
    } else {
        l = left + letter * sideLength;
        t = top + (7 - number) * sideLength;
    }
    return CGPointMake(l, t);
}
- (SFMSquare)squareForCoordinates:(NSPoint)point
                    leftOffset:(CGFloat)left
                     topOffset:(CGFloat)top
                    sideLength:(CGFloat)sideLength
{
    int letter, number;
    if (self.boardIsFlipped) {
        letter = (int) (point.x - left) / (int) sideLength;
        letter = 7 - letter;
        number = (int) (point.y - top) / (int) sideLength;
    } else {
        letter = (int) (point.x - left) / (int) sideLength;
        number = (int) (point.y - top) / (int) sideLength;
        number = 7 - number;
    }
    if (!(letter >= 0 && letter <= 7 && number >= 0 && number <= 7)) {
        return SQ_NONE;
    }
    return 8 * number + letter;
}

#pragma mark - Interaction

- (void)mouseDown:(NSEvent *)theEvent
{
    self.isDragging = NO;
    
    // Figure out which square you clicked on
    NSPoint clickLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    SFMSquare clickedSquare = [self squareForCoordinates:clickLocation
                                              leftOffset:self.leftInset
                                               topOffset:self.topInset
                                              sideLength:self.squareSideLength];
    
    if ([self.highlightedSquares count] == 0) {
        // You haven't selected a valid piece, since there are no highlighted squares on the board.
        if (clickedSquare != SQ_NONE) {
            self.fromSquare = clickedSquare;
            self.highlightedSquares = [self.position legalSquaresFromSquare:clickedSquare];
        }
    } else {
        // Is it possible to move to the square you clicked on?
        BOOL isValidMove = [self.highlightedSquares containsObject:
                            [NSNumber numberWithInteger:clickedSquare]];
        
        if (!isValidMove) {
            // If it's not a valid move, cancel the highlight
            self.highlightedSquares = nil;
            self.fromSquare = SQ_NONE;
        }

    }
    
    [self setNeedsDisplay:YES];
    
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    self.isDragging = YES;
    
    // Make the dragged piece follow the mouse
    NSPoint mouseLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    // Center the piece
    mouseLocation.x -= self.squareSideLength / 2;
    mouseLocation.y -= self.squareSideLength / 2;
    
    NSView *draggedPiece = self.pieceViews[[NSNumber numberWithInteger:self.fromSquare]];
    [draggedPiece setFrameOrigin:mouseLocation];
}

- (void)mouseUp:(NSEvent *)theEvent
{
    // Figure out which square you let go on
    NSPoint upLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    self.toSquare = [self squareForCoordinates:upLocation
                                    leftOffset:self.leftInset
                                     topOffset:self.topInset
                                    sideLength:self.squareSideLength];
    
    // Is it possible to move to the square you clicked on?
    BOOL isValidMove = [self.highlightedSquares
                        containsObject:[NSNumber numberWithInteger:_toSquare]];
    
    if (isValidMove) {
        self.isDragging = NO;
        
        // You previously selected a valid piece, and now you're trying to move it
        
        SFMPieceType pieceType = NO_PIECE_TYPE;
        
        // Handle promotions
        if ([self.position isPromotion:
             [[SFMMove alloc] initWithFrom:self.fromSquare to:self.toSquare]]) {
            pieceType = [self.dataSource promotionPieceTypeForBoardView:self];
        }
        
        // HACK: Castling. The user probably tries to move the king two squares to
        // the side when castling, but Stockfish internally encodes castling moves
        // as "king captures rook". We handle this by adjusting tSq when the user
        // tries to move the king two squares to the side:
        BOOL castle = NO;
        
        if (self.fromSquare == SQ_E1 && self.toSquare == SQ_G1 &&
            [self.position pieceOnSquare:self.fromSquare] == WK) {
            self.toSquare = SQ_H1;
            castle = YES;
        } else if (self.fromSquare == SQ_E1 && self.toSquare == SQ_C1 &&
                   [self.position pieceOnSquare:self.fromSquare] == WK) {
            self.toSquare = SQ_A1;
            castle = YES;
        } else if (self.fromSquare == SQ_E8 && self.toSquare == SQ_G8 &&
                   [self.position pieceOnSquare:self.fromSquare] == BK) {
            self.toSquare = SQ_H8;
            castle = YES;
        } else if (self.fromSquare == SQ_E8 && self.toSquare == SQ_C8 &&
                   [self.position pieceOnSquare:self.fromSquare] == BK) {
            self.toSquare = SQ_A8;
            castle = YES;
        }
        
        self.highlightedSquares = @[];
        
        SFMMove *move;
        if (pieceType != NO_PIECE_TYPE) {
            move = [[SFMMove alloc] initWithFrom:self.fromSquare to:self.toSquare
                                       promotion:pieceType];
        } else {
            move = [[SFMMove alloc] initWithFrom:self.fromSquare to:self.toSquare];
            if (castle) {
                move.isCastle = YES;
            }
        }
        
        [self.delegate boardView:self userDidMove:move];
    } else if (self.isDragging) {
        // Invalid move
        self.isDragging = NO;
        self.highlightedSquares = nil;
        self.fromSquare = SQ_NONE;
        self.toSquare = SQ_NONE;
    }
    
    [self setNeedsDisplay:YES];
    [self resizeSubviewsWithOldSize:NSMakeSize(0, 0)];
    
}

// TODO delete this

// Sets the piece view's square property and executes an animated move
//- (void)movePieceView:(SFMPieceView *)pieceView toSquare:(SFMSquare)square
//{
//    pieceView.square = square;
//    [pieceView moveTo:[self coordinatesForSquare:square leftOffset:self.leftInset topOffset:self.topInset sideLength:self.squareSideLength]];
//}
//
//- (void)animatePieceOnSquare:(SFMSquare)fromSquare
//                          to:(SFMSquare)toSquare
//                   promotion:(SFMPieceType)desiredPromotionPiece
//                shouldCastle:(BOOL)shouldCastle
//{
//    
//    // Find the piece(s)
//    SFMPieceView *thePiece = [self pieceViewOnSquare:fromSquare];
//    SFMPieceView *capturedPiece = [self pieceViewOnSquare:toSquare];
//    
//    if (shouldCastle) {
//        // Castle
//        if (toSquare == SQ_H1) {
//            // White kingside
//            [self movePieceView:[self pieceViewOnSquare:SQ_H1] toSquare:SQ_F1]; // Rook
//            [self movePieceView:thePiece toSquare:SQ_G1]; // King
//            
//        } else if (toSquare == SQ_A1) {
//            // White queenside
//            [self movePieceView:[self pieceViewOnSquare:SQ_A1] toSquare:SQ_D1]; // Rook
//            [self movePieceView:thePiece toSquare:SQ_C1]; // King
//            
//        } else if (toSquare == SQ_H8) {
//            // Black kingside
//            [self movePieceView:[self pieceViewOnSquare:SQ_H8] toSquare:SQ_F8]; // Rook
//            [self movePieceView:thePiece toSquare:SQ_G8]; // King
//            
//        } else {
//            // Black queenside
//            [self movePieceView:[self pieceViewOnSquare:SQ_A8] toSquare:SQ_D8]; // Rook
//            [self movePieceView:thePiece toSquare:SQ_C8]; // King
//            
//        }
//    } else if (desiredPromotionPiece != NO_PIECE_TYPE) {
//        // Promotion
//        
//        // Remove all relevant pieces
//        [thePiece removeFromSuperview];
//        [self.pieces removeObject:thePiece];
//        
//        if (capturedPiece) {
//            // You could capture while promoting
//            [capturedPiece removeFromSuperview];
//            [self.pieces removeObject:capturedPiece];
//        }
//        
//        // Create a new piece view and add it
//        SFMPieceView *pieceView = [[SFMPieceView alloc] initWithPieceType:piece_of_color_and_type(self.position->side_to_move(), desiredPromotionPiece) onSquare:toSquare];
//        [self addSubview:pieceView];
//        [self.pieces addObject:pieceView];
//    } else if (capturedPiece) {
//        // Capture
//        
//        // Remove the captured piece
//        [capturedPiece removeFromSuperview];
//        [self.pieces removeObject:capturedPiece];
//        
//        // Do a normal move
//        [self movePieceView:thePiece toSquare:toSquare];
//    } else if (type_of_piece(self.position->piece_on(fromSquare)) == PAWN &&
//               square_file(fromSquare) != square_file(toSquare)) {
//        // En passant
//        
//        // Find the en passant square
//        Square enPassantSquare = toSquare - pawn_push(self.position->side_to_move());
//        
//        // Remove the piece on that square
//        SFMPieceView *toRemove = [self pieceViewOnSquare:enPassantSquare];
//        [toRemove removeFromSuperview];
//        [self.pieces removeObject:toRemove];
//        
//        // Do a normal move
//        [self movePieceView:thePiece toSquare:toSquare];
//    } else {
//        // Normal move
//        [self movePieceView:thePiece toSquare:toSquare];
//    }
//    
//}

#pragma mark - Misc

- (BOOL)isFlipped
{
    return YES;
}

@end
