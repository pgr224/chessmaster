import { Hono } from 'hono'
import { Env } from '../index'
import { v4 as uuidv4 } from 'uuid'

export const pushRoutes = new Hono<{ Bindings: Env }>()

type PushCategorySettings = {
  challenges: boolean
  community: boolean
  tournaments: boolean
  system: boolean
}

const defaultCategorySettings: PushCategorySettings = {
  challenges: true,
  community: true,
  tournaments: true,
  system: true,
}

// Public VAPID key for web push subscription bootstrap
pushRoutes.get('/vapid-public-key', async (c) => {
  return c.json({ publicKey: c.env.VAPID_PUBLIC_KEY })
})

// Subscribe to push notifications
pushRoutes.post('/subscribe', async (c) => {
  const { userId, subscription, deviceId } = await c.req.json()
  
  if (!userId || !subscription || !subscription.endpoint) {
    return c.json({ error: 'Missing required subscription fields' }, 400)
  }

  const { endpoint, keys } = subscription
  const p256dh = keys?.p256dh
  const auth = keys?.auth

  if (!p256dh || !auth) {
    return c.json({ error: 'Subscription keys missing' }, 400)
  }

  const id = uuidv4()
  
  // Upsert subscription: Check if this endpoint already exists for this user/device
  const existing = await c.env.DB.prepare(
    'SELECT id FROM user_subscriptions WHERE user_id = ? AND endpoint = ?'
  ).bind(userId, endpoint).first()

  if (existing) {
     await c.env.DB.prepare(
      'UPDATE user_subscriptions SET p256dh = ?, auth = ?, device_id = ? WHERE id = ?'
    ).bind(p256dh, auth, deviceId || null, (existing as any).id).run()
    return c.json({ status: 'updated', id: (existing as any).id })
  }

  await c.env.DB.prepare(
    'INSERT INTO user_subscriptions (id, user_id, endpoint, p256dh, auth, device_id) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(id, userId, endpoint, p256dh, auth, deviceId || null).run()

  return c.json({ status: 'subscribed', id }, 201)
})

// Unsubscribe
pushRoutes.post('/unsubscribe', async (c) => {
  const { userId, endpoint } = await c.req.json()
  
  await c.env.DB.prepare(
    'DELETE FROM user_subscriptions WHERE user_id = ? AND endpoint = ?'
  ).bind(userId, endpoint).run()

  return c.json({ status: 'unsubscribed' })
})

// Toggle overall push preference
pushRoutes.get('/settings', async (c) => {
  const userId = c.req.query('userId')
  if (!userId) {
    return c.json({ error: 'userId is required' }, 400)
  }

  const user = await c.env.DB.prepare(
    'SELECT push_enabled FROM users WHERE id = ?'
  ).bind(userId).first<{ push_enabled: number }>()

  if (!user) {
    return c.json({ error: 'User not found' }, 404)
  }

  const prefs = await c.env.DB.prepare(
    `SELECT challenge_notifications, community_notifications,
            tournament_notifications, system_notifications
     FROM user_notification_preferences
     WHERE user_id = ?`
  ).bind(userId).first<{
    challenge_notifications: number
    community_notifications: number
    tournament_notifications: number
    system_notifications: number
  }>()

  return c.json({
    enabled: user.push_enabled === 1,
    categories: {
      challenges: prefs ? prefs.challenge_notifications === 1 : true,
      community: prefs ? prefs.community_notifications === 1 : true,
      tournaments: prefs ? prefs.tournament_notifications === 1 : true,
      system: prefs ? prefs.system_notifications === 1 : true,
    },
  })
})

pushRoutes.put('/settings', async (c) => {
  const { userId, enabled, categories } = await c.req.json<{
    userId?: string
    enabled?: boolean
    categories?: Partial<PushCategorySettings>
  }>()

  if (!userId) {
    return c.json({ error: 'userId is required' }, 400)
  }

  const resolvedCategories: PushCategorySettings = {
    ...defaultCategorySettings,
    ...(categories ?? {}),
  }
  
  await c.env.DB.prepare(
    'UPDATE users SET push_enabled = ? WHERE id = ?'
  ).bind(enabled == false ? 0 : 1, userId).run()

  await c.env.DB.prepare(
    `INSERT INTO user_notification_preferences (
        user_id,
        challenge_notifications,
        community_notifications,
        tournament_notifications,
        system_notifications,
        updated_at
      ) VALUES (?, ?, ?, ?, ?, datetime('now'))
      ON CONFLICT(user_id) DO UPDATE SET
        challenge_notifications = excluded.challenge_notifications,
        community_notifications = excluded.community_notifications,
        tournament_notifications = excluded.tournament_notifications,
        system_notifications = excluded.system_notifications,
        updated_at = datetime('now')`
  ).bind(
    userId,
    resolvedCategories.challenges ? 1 : 0,
    resolvedCategories.community ? 1 : 0,
    resolvedCategories.tournaments ? 1 : 0,
    resolvedCategories.system ? 1 : 0,
  ).run()

  return c.json({
    status: 'updated',
    enabled: enabled == false ? false : true,
    categories: resolvedCategories,
  })
})
