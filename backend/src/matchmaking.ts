export interface QueuedPlayer {
  id: string;
  username: string;
  rating: number;
  timeControl: string;
  joinedAt: number;
  socket: WebSocket;
}

export class Matchmaker {
  private queue: QueuedPlayer[] = [];

  public add(player: QueuedPlayer): void {
    // Basic deduplication
    this.queue = this.queue.filter(p => p.id !== player.id);
    this.queue.push(player);
  }

  public remove(playerId: string): void {
    this.queue = this.queue.filter(p => p.id !== playerId);
  }

  public findMatches(): Array<[QueuedPlayer, QueuedPlayer]> {
    const matches: Array<[QueuedPlayer, QueuedPlayer]> = [];
    const now = Date.now();
    
    // Sort by join time
    this.queue.sort((a, b) => a.joinedAt - b.joinedAt);

    const used = new Set<string>();

    for (let i = 0; i < this.queue.length; i++) {
      const p1 = this.queue[i];
      if (used.has(p1.id)) continue;

      const waitTime = (now - p1.joinedAt) / 1000;
      let range = 50;
      if (waitTime > 10) range = 200;
      else if (waitTime > 5) range = 100;

      for (let j = i + 1; j < this.queue.length; j++) {
        const p2 = this.queue[j];
        if (used.has(p2.id)) continue;

        const ratingDiff = Math.abs(p1.rating - p2.rating);
        const sameTimeControl = p1.timeControl === p2.timeControl;
        if (ratingDiff <= range && sameTimeControl) {
          matches.push([p1, p2]);
          used.add(p1.id);
          used.add(p2.id);
          break;
        }
      }
    }

    // Update queue to remove matched players
    this.queue = this.queue.filter(p => !used.has(p.id));

    return matches;
  }

  public getQueueCount(): number {
    return this.queue.length;
  }
}
