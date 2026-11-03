import onUserCreate from '../../onUserCreate/src/main.js';
import partnerView from '../../partnerView/src/main.js';
import chatSystemMessages from '../../chatSystemMessages/src/main.js';
import notifications from '../../notifications/src/main.js';
import { createEventsHandler } from './dispatch.js';

// Events: users.*.create and the partnerView / chatSystemMessages table
// events. Schedule: */30 * * * * (UTC) for notifications.
export default createEventsHandler({ onUserCreate, partnerView, chatSystemMessages, notifications });
