# Use the base ONOS image
FROM onosproject/onos:2.7-latest

# Environment variable
ENV ONOS=/root/onos

# Activates necessary applications
RUN touch $ONOS/apps/org.onosproject.openflow-base/active \
    touch $ONOS/apps/org.onosproject.openflow-message/active \
    touch $ONOS/apps/org.onosproject.ofagent/active \
    touch $ONOS/apps/org.onosproject.openflow/active \
    touch $ONOS/apps/org.onosproject.workflow.ofoverlay/active \
    touch $ONOS/apps/org.onosproject.fwd/active

# Default command to run ONOS
CMD ["onos"]