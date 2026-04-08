/**
 * Player Name Synchronization Module
 *
 * Handles real-time synchronization of player names across game rooms, 
 * tournaments, and leaderboards. Ensures consistency when players change
 * their usernames in the profile.
 */

import type { Env } from './index'

export interface PlayerNameChange {
  userId: string
  oldName: string
  newName: string
  changedAt: number
}

/**
 * Fetch current username from database
 * Single source of truth for player names
 */
export async function getPlayerUsername(env: Env, userId: string): Promise<string | null> {
  try {
    const result = await env.DB.prepare('SELECT username FROM users WHERE id = ?')
      .bind(userId)
      .first<{ username: string }>()
    return result?.username ?? null
  } catch (err) {
    console.error(`[PlayerNameSync] Failed to fetch username for ${userId}:`, err)
    return null
  }
}

/**
 * Refresh player names in a data structure
 * Used by game rooms and tournament rooms to sync names
 */
export async function refreshPlayerNames(
  env: Env,
  players: Array<{ id: string; username?: string; name?: string }>,
  nameField: 'username' | 'name' = 'username'
): Promise<PlayerNameChange[]> {
  const changes: PlayerNameChange[] = []
  const now = Date.now()

  for (const player of players) {
    const oldName = player[nameField] || 'Player'
    const newName = await getPlayerUsername(env, player.id)

    if (newName && newName !== oldName) {
      changes.push({
        userId: player.id,
        oldName,
        newName,
        changedAt: now,
      })
      player[nameField] = newName
    }
  }

  return changes
}

/**
 * Format a name change notification for WebSocket broadcast
 */
export function formatNameChangeNotification(change: PlayerNameChange) {
  return {
    type: 'PLAYER_NAME_CHANGED',
    data: {
      userId: change.userId,
      oldName: change.oldName,
      newName: change.newName,
      changedAt: change.changedAt,
    },
  }
}

/**
 * Validate that a name change is legitimate
 * (player ID matches the user making the change)
 */
export function isValidNameChangeByPlayer(userId: string, authUserId: string): boolean {
  return userId === authUserId
}
