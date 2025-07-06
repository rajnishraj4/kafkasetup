#!/usr/bin/env bash

# ✅ Ensure Bash
if [[ -z "$BASH_VERSION" ]]; then
  echo "❌ Please run this script with bash: bash ./init-kraft.sh"
  exit 1
fi

echo "🔧 Kafka KRaft Init Script (per-node kraft.properties)"
mkdir -p config data

# ✅ Generate cluster ID, strip all whitespace
echo "📌 Generating new cluster.id..."
cluster_id=$(docker run --rm bitnami/kafka:3.7.0 bash -c "/opt/bitnami/kafka/bin/kafka-storage.sh random-uuid" | tr -d '\r\n')
echo "✅ Generated cluster.id: $cluster_id"

# ✅ Define per-node IDs (controllers 1–3, brokers 4–6)
declare -A NODE_IDS=(
  [controller1]=1
  [controller2]=2
  [controller3]=3
  [broker1]=4
  [broker2]=5
  [broker3]=6
)

# 🔁 Iterate over each node
for node in "${!NODE_IDS[@]}"; do
  node_id=${NODE_IDS[$node]}
  mkdir -p config/$node data/$node

  echo "⚙️  Generating config for $node"

  if [[ $node == controller* ]]; then
    cat > config/$node/kraft.properties <<EOF
process.roles=controller
node.id=$node_id
controller.quorum.voters=1@controller1:9093,2@controller2:9093,3@controller3:9093
controller.listener.names=CONTROLLER
listeners=CONTROLLER://:9093
inter.broker.listener.name=CONTROLLER
log.dirs=/bitnami/kafka/data
EOF
  else
    cat > config/$node/kraft.properties <<EOF
process.roles=broker
node.id=$node_id
controller.quorum.voters=1@controller1:9093,2@controller2:9093,3@controller3:9093
controller.listener.names=CONTROLLER
listeners=PLAINTEXT://:9094
advertised.listeners=PLAINTEXT://$node:9094
inter.broker.listener.name=PLAINTEXT
log.dirs=/bitnami/kafka/data
EOF
  fi

  echo "✅ Created ./config/$node/kraft.properties"

  echo "🛠 Formatting $node with cluster.id=$cluster_id"
  docker run --rm \
    -v "$(pwd)/data/$node:/bitnami/kafka/data" \
    -v "$(pwd)/config/$node:/bitnami/kafka/config" \
    bitnami/kafka:3.7.0 \
    bash -c "/opt/bitnami/kafka/bin/kafka-storage.sh format --cluster-id=$cluster_id --config=/bitnami/kafka/config/kraft.properties"

  echo "✅ Formatted $node"
done

echo "🎉 All nodes formatted successfully with cluster.id=$cluster_id"

