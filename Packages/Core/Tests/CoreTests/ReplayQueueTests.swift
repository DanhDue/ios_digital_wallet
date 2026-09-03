import XCTest
@testable import Core

final class ReplayQueueTests: XCTestCase {
    // MARK: FIFO ordering

    func testPreservesFIFOOrderForSequentialEnqueue() async {
        let queue = ReplayQueue<Int>()
        for number in 1 ... 5 {
            await queue.enqueue(number)
        }
        let drained = await queue.dequeueAll()
        XCTAssertEqual(drained, [1, 2, 3, 4, 5])
    }

    // MARK: drain / teardown semantics

    func testDequeueAllDrainsSoSecondCallReturnsEmpty() async {
        let queue = ReplayQueue<Int>()
        await queue.enqueue(1)
        await queue.enqueue(2)

        let first = await queue.dequeueAll()
        let second = await queue.dequeueAll()

        XCTAssertEqual(first, [1, 2])
        XCTAssertTrue(second.isEmpty, "queue must hold nothing after a drain")
    }

    func testDequeueAllOnEmptyQueueReturnsEmpty() async {
        let queue = ReplayQueue<Int>()
        let drained = await queue.dequeueAll()
        XCTAssertTrue(drained.isEmpty)
    }

    // MARK: async / race

    func testConcurrentEnqueueFromManyTasksThenDequeueAllReturnsEveryItemOnce() async {
        let queue = ReplayQueue<Int>()
        let count = 200

        await withTaskGroup(of: Void.self) { group in
            for value in 0 ..< count {
                group.addTask { await queue.enqueue(value) }
            }
        }

        let drained = await queue.dequeueAll()
        XCTAssertEqual(drained.count, count, "no lost items")
        XCTAssertEqual(Set(drained), Set(0 ..< count), "no dropped or duplicated items")
    }

    func testEnqueueInterleavedWithDequeueAllNeverLosesOrDuplicates() async {
        let queue = ReplayQueue<Int>()
        let total = 300

        let collected = await withTaskGroup(of: [Int].self) { group -> [Int] in
            group.addTask {
                for value in 0 ..< total {
                    await queue.enqueue(value)
                    await Task.yield()
                }
                return []
            }
            group.addTask {
                var drained: [Int] = []
                for _ in 0 ..< total {
                    drained += await queue.dequeueAll()
                    await Task.yield()
                }
                return drained
            }

            var accumulator: [Int] = []
            for await partial in group {
                accumulator += partial
            }
            return accumulator
        }

        let stragglers = await queue.dequeueAll()
        let everything = collected + stragglers
        XCTAssertEqual(everything.sorted(), Array(0 ..< total))
    }
}
