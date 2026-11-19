// SPDX-License-Identifier: Apache-2.0
#include "MWAssistantVideoArea.h"
#include <assert.h>

int main(void) {
    assert(MWIsInterviewAssistant("com.saasau.interviewopus"));
    assert(MWIsInterviewAssistant("com.saasau.interviewopus.standard"));
    assert(!MWIsInterviewAssistant("com.bytedance.ee.lark"));
    assert(!MWIsInterviewAssistant("com.saasau.interviewopus.beta"));
    assert(!MWIsInterviewAssistant(NULL));
    for (int width = 180; width <= 1000; width += 10) {
        for (int height = 180; height <= 1000; height += 10) {
            MWRect full = {14, 32, width, height};
            MWRect app = MWAssistantContentRect(full);
            assert(app.x == full.x && app.y >= full.y && app.width <= width);
            assert(app.y + app.height == full.y + height);
            assert(app.width * app.height >= .72 * width * height - 1);
            if (width > height && width >= 400) {
                assert(app.width >= 300 && app.width <= width - 100);
                assert(app.y == full.y);
            } else if (height >= 360) {
                assert(app.height >= 300 && app.y >= full.y + 60 && app.width == width);
            } else {
                assert(app.width == width && app.height == height);
            }
        }
    }
}
