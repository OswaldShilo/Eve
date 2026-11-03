import partnerInvites from '../../partnerInvites/src/main.js';
import sendChatMessage from '../../sendChatMessage/src/main.js';
import aiProxy from '../../aiProxy/src/main.js';
import { createApiHandler } from './dispatch.js';

// Executed by signed-in users with { route, ...body } (see AppwriteService.executeJson).
export default createApiHandler({ partnerInvites, sendChatMessage, aiProxy });
