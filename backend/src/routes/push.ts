import { Hono } from 'hono'
import { Env } from '../index'
import { v4 as uuidv4 } from 'uuid'

export const pushRoutes = new Hono<{ Bindings: Env }>()

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
pushRoutes.put('/settings', async (c) => {
  const { userId, enabled } = await c.req.json()
  
  await c.env.DB.prepare(
    'UPDATE users SET push_enabled = ? WHERE id = ?'
  ).bind(enabled ? 1 : 0, userId).run()

  return c.json({ status: 'updated' })
})
