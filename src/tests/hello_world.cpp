/*
 * MIT License
 *
 * Copyright (c) 2023 Rafael Antoniello
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <cstdio>
#include <cstdlib>
#include <string>
#include <MQTTClient.h>

using namespace ::testing;
using ::testing::_;
using ::testing::Return;

class Tests_hello_world : public ::testing::Test {
protected:

    Tests_hello_world()
    {
    }

    virtual ~Tests_hello_world() {
    }

public:
};

TEST_F(Tests_hello_world, publish)
{
    const char *client_id = "ExampleClientPub";
    const unsigned long tout = 10000L;
    const char *topic = "MQTT Examples";

    MQTTClient client;
    MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;
    MQTTClient_message pubmsg = MQTTClient_message_initializer;
    MQTTClient_deliveryToken token;
    int rc;

    MQTTClient_create(&client, "tcp://localhost:1883", client_id,
            MQTTCLIENT_PERSISTENCE_NONE, nullptr);
    conn_opts.keepAliveInterval = 20;
    conn_opts.cleansession = 1;

    // Connect client to broker
    rc = MQTTClient_connect(client, &conn_opts);
    ASSERT_EQ(rc, MQTTCLIENT_SUCCESS);

    // Compose message and publish
    const char *payload = "Hello World!";
    pubmsg.payload = (char*)payload;
    pubmsg.payloadlen = strlen(payload);
    pubmsg.qos = 1;
    pubmsg.retained = 0;
    MQTTClient_publishMessage(client, topic, &pubmsg, &token);

    // Waiting for up to 'tout/1000' seconds for publication of 'Hello World!'
    // message on topic 'MQTT Examples' for client with client_id
    // 'ExampleClientPub'
    rc = MQTTClient_waitForCompletion(client, token, tout);
    ASSERT_EQ(rc, MQTTCLIENT_SUCCESS);

    // clean-up
    MQTTClient_disconnect(client, 10000);
    MQTTClient_destroy(&client);
}
