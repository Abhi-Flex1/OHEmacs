#ifndef OHEMACS_BRIDGE_H
#define OHEMACS_BRIDGE_H

#include <cstdint>
#include <string>

// Emacs upstream version we are porting.
#define OHEMACS_UPSTREAM_VERSION "30.1"
#define OHEMACS_PORT_VERSION "0.1.0-ohos-gui-scaffold"

// Called once from ArkTS to configure sandbox paths (filesDir/cacheDir).
// Returns human-readable status; never throws.
std::string OhemacsInit(const std::string &filesDir, const std::string &cacheDir);

// Synthetic input injection used by UI buttons and later by XComponent callbacks.
// keyCode uses OH XComponent KEY_* numbering (e.g. 2017 = A).
void OhemacsSendKey(int32_t keyCode, int32_t action);
void OhemacsSendExpose();

// Render state queries for tests.
int OhemacsSurfaceWidth();
int OhemacsSurfaceHeight();
uint64_t OhemacsFrameCounter();

#endif // OHEMACS_BRIDGE_H
