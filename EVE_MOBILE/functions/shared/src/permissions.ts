import { Permission, Role } from 'node-appwrite';
import type { Row } from './db.js';

/** Rows she writes herself (logs): read/update/delete for her only. */
export function ownerPermissions(uid: string): string[] {
  return [Permission.read(Role.user(uid)), Permission.update(Role.user(uid)), Permission.delete(Role.user(uid))];
}

/** Singleton rows she may edit but never delete (profile, preferences, ...). */
export function ownerEditable(uid: string): string[] {
  return [Permission.read(Role.user(uid)), Permission.update(Role.user(uid))];
}

/** Server-written rows only she can see. */
export function ownerReadOnly(uid: string): string[] {
  return [Permission.read(Role.user(uid))];
}

/** Server-written rows several users can see (partner view, chat). */
export function readersPermissions(uids: string[]): string[] {
  return uids.map((uid) => Permission.read(Role.user(uid)));
}

/**
 * True when `uid` holds update permission on the row. Appwrite only lets a
 * client grant permissions to roles it belongs to, so for a client-created
 * row this proves who created it — the `userId` column alone proves nothing.
 */
export function isOwnedBy(row: Pick<Row, '$permissions'>, uid: string): boolean {
  return row.$permissions.includes(Permission.update(Role.user(uid)));
}
