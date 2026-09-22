#include <cstdio>
#include <cstring>

#include "vxw_hdrs.h"
#include "sysLib.h"
#include "tickLib.h"

namespace
{

    SEM_ID worker_semaphore;
    int worker_completed;

    void *pthread_worker(void *)
    {
        if (semTake(worker_semaphore, WAIT_FOREVER) == OK)
        {
            worker_completed = 1;
        }
        return nullptr;
    }

    bool test_semaphore_and_pthread()
    {
        worker_semaphore = semBCreate(SEM_Q_FIFO, SEM_EMPTY);
        if (worker_semaphore == nullptr)
        {
            return false;
        }

        pthread_t worker;
        const int create_status = pthread_create(&worker, nullptr, pthread_worker, nullptr);
        const STATUS give_status = create_status == 0 ? semGive(worker_semaphore) : ERROR;
        const int join_status = create_status == 0 ? pthread_join(worker, nullptr) : ERROR;
        const STATUS delete_status = semDelete(worker_semaphore);
        return create_status == 0 && give_status == OK && join_status == 0 &&
               delete_status == OK && worker_completed == 1;
    }

    bool test_message_queue()
    {
        MSG_Q_ID queue = msgQCreate(1, 32, MSG_Q_FIFO);
        if (queue == nullptr)
        {
            return false;
        }

        char received[32] = {};
        char message[] = "static message queue";
        const STATUS send_status = msgQSend(queue, message, sizeof(message), NO_WAIT, MSG_PRI_NORMAL);
        const int receive_status = send_status == OK
                                       ? msgQReceive(queue, received, sizeof(received), NO_WAIT)
                                       : ERROR;
        const STATUS delete_status = msgQDelete(queue);
        return send_status == OK && receive_status == static_cast<int>(sizeof(message)) &&
               std::strcmp(received, message) == 0 && delete_status == OK;
    }

    bool test_clock_and_ticks()
    {
        const int clock_rate = sysClkRateGet();
        const ULONG before = tickGet();
        const STATUS delay_status = taskDelay(1);
        const ULONG after = tickGet();
        return clock_rate > 0 && delay_status == OK && after >= before;
    }

} // namespace

int main()
{
    if (v2lin_init() != OK)
    {
        std::fprintf(stderr, "v2lin_init failed\n");
        return 1;
    }

    if (!test_semaphore_and_pthread() || !test_message_queue() || !test_clock_and_ticks())
    {
        std::fprintf(stderr, "static C++ smoke test failed\n");
        return 1;
    }

    std::puts("static C++ smoke test passed");
    return 0;
}