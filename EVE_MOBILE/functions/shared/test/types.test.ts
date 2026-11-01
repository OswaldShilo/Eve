import { describe, expect, it } from 'vitest';
import { DATABASE_ID, FUNCTION_IDS, TABLES } from '../src/ids.js';
import { MOODS, NOTIFICATION_TYPES, PERMISSION_CATEGORIES, LIFE_STAGES } from '../src/types.js';

describe('ids', () => {
  it('uses the canonical database and table IDs from design-spec §10', () => {
    expect(DATABASE_ID).toBe('eve');
    expect(Object.values(TABLES).sort()).toEqual([
      'chat_messages',
      'life_stage_profiles',
      'partner_links',
      'partner_lookups',
      'partner_permissions',
      'partner_views',
      'preferences',
      'profiles',
      'symptom_logs',
    ]);
  });

  it('lists every function ID', () => {
    expect(Object.values(FUNCTION_IDS).sort()).toEqual([
      'aiProxy',
      'chatSystemMessages',
      'notifications',
      'onUserCreate',
      'partnerInvites',
      'partnerView',
      'sendChatMessage',
    ]);
  });
});

describe('canonical vocabularies', () => {
  it('matches design-spec §10', () => {
    expect(LIFE_STAGES).toEqual(['cycle', 'conceive', 'pregnant', 'postpartum', 'menopause']);
    expect(MOODS).toEqual(['great', 'good', 'okay', 'low', 'difficult']);
    expect(NOTIFICATION_TYPES).toHaveLength(9);
    expect(PERMISSION_CATEGORIES).toEqual([
      'appointmentReminders',
      'pregnancyMilestones',
      'supportSuggestions',
      'moodUpdates',
    ]);
  });
});
