require "test_helper"
require "open3"

class PublicLoopShotsTest < ActiveSupport::TestCase
  test "report records landmarks, headings, tap targets, font size and reduced motion" do
    source = Rails.root.join("script/qa/public_loop_shots.cjs").read
    %w[mains headings smallTaps minFont].each do |metric|
      assert_includes source, "#{metric}: m.#{metric}"
    end
    assert_includes source, "extra.reducedMotionScroll"
    assert_includes source, "reducedMotion: 'reduce'"
  end

  test "both viewports always include notfound and include photogone only when ux-photo exists" do
    output, status = Open3.capture2e("node", "-e", <<~JS, Rails.root.join("script/qa/public_loop_shots.cjs").to_s)
      const assert = require('node:assert/strict');
      const fs = require('node:fs');
      const vm = require('node:vm');

      const base = 'https://example.test';
      const source = fs.readFileSync(process.argv[1], 'utf8');
      const noop = () => {};

      async function checkTargets(sampleStatus) {
        const visits = [];
        const chromium = {
          launch: () => ({
            close: noop,
            newContext: ({ viewport }) => ({
              close: noop,
              newPage: () => {
                let url;
                const locator = {
                  evaluate: () => -1,
                  evaluateAll: noop,
                  click: noop
                };
                locator.first = () => locator;
                return {
                  goto: async nextUrl => {
                    url = nextUrl;
                    visits.push([viewport.width, new URL(url).pathname]);
                  },
                  url: () => url,
                  on: noop,
                  waitForTimeout: noop,
                  evaluate: () => ({}),
                  locator: () => locator,
                  screenshot: noop,
                  fill: noop,
                  getByText: () => ({ isVisible: noop })
                };
              }
            })
          })
        };

        await vm.runInNewContext(source, {
          require: name => ({ playwright: { chromium }, fs: { mkdirSync: noop, writeFileSync: noop } })[name],
          process: { argv: ['node', 'public_loop_shots.cjs', base, '/unused'] },
          fetch: async () => ({ status: sampleStatus }),
          console: { log: noop },
          URL
        });

        const trackedPaths = ['/ux-photo', '/404.html', '/p/ux-photo/99999999'];
        const expectedPaths = sampleStatus === 200 ? trackedPaths : ['/404.html'];
        assert.deepEqual(
          visits.filter(([, path]) => trackedPaths.includes(path)),
          [1440, 390].flatMap(width => expectedPaths.map(path => [width, path]))
        );
      }

      (async () => {
        await checkTargets(200);
        await checkTargets(404);
      })().catch(error => {
        console.error(error);
        process.exitCode = 1;
      });
    JS

    assert status.success?, output
  end
end
