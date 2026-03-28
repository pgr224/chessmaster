import { Chess } from 'chess.js';

export interface Move {
  from: string;
  to: string;
  promotion?: string;
}

export class ChessValidator {
  private game: Chess;

  constructor(fen?: string) {
    this.game = new Chess(fen);
  }

  public validateMove(move: Move): { valid: boolean; fen: string; pgn: string; gameOver: boolean; result?: string } {
    try {
      const result = this.game.move(move);
      if (!result) return { valid: false, fen: this.game.fen(), pgn: this.game.pgn(), gameOver: false };

      const isCheckmate = this.game.isCheckmate();
      const isDraw = this.game.isDraw();
      const isGameOver = isCheckmate || isDraw;

      let gameResult: string | undefined;
      if (isCheckmate) {
        gameResult = this.game.turn() === 'w' ? 'black' : 'white';
      } else if (isDraw) {
        gameResult = 'draw';
      }

      return {
        valid: true,
        fen: this.game.fen(),
        pgn: this.game.pgn(),
        gameOver: isGameOver,
        result: gameResult
      };
    } catch (e) {
      return { valid: false, fen: this.game.fen(), pgn: this.game.pgn(), gameOver: false };
    }
  }

  public getFen(): string {
    return this.game.fen();
  }

  public getPgn(): string {
    return this.game.pgn();
  }

  public isGameOver(): boolean {
    return this.game.isGameOver();
  }

  public getMoveCount(): number {
    return this.game.moveNumber();
  }
  public undo(): string {
    this.game.undo();
    return this.game.fen();
  }
}
