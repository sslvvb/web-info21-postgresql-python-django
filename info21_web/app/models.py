from django.db import models
from django.apps import apps


def get_table_names() -> list:
    excluded_tables = ['django_admin_log', 'auth_permission', 'auth_group',
                       'auth_user', 'django_content_type', 'django_session']
    app_models = apps.get_models()
    table_names: list = [model._meta.db_table for model in app_models if model._meta.db_table not in excluded_tables]
    return table_names


class Peers(models.Model):
    nickname = models.CharField(primary_key=True,
                                unique=True, db_column="nickname")
    birthday = models.DateField(db_column="birthday")

    class Meta:
        db_table = "peers"
        managed = False

    def __str__(self):
        return self.nickname


class Tasks(models.Model):
    title = models.CharField(primary_key=True, unique=True, db_column="title")
    maxxp = models.BigIntegerField(default=0, null=False, db_column="maxxp")
    parenttask = models.ForeignKey('self', on_delete=models.CASCADE, null=True,
                                   blank=True, db_column="parenttask")

    class Meta:
        db_table = 'tasks'
        managed = False

    def __str__(self):
        return self.title


class Checks(models.Model):
    # id autoadded
    peer = models.ForeignKey(Peers, on_delete=models.CASCADE,
                             null=False, db_column="peer")
    task = models.ForeignKey(Tasks, on_delete=models.CASCADE,
                             null=False, db_column="task")
    date = models.DateField(db_column="date")

    class Meta:
        db_table = 'checks'
        managed = False
    
    def __str__(self):
        return f"{self.id}"


class CheckStatus(models.TextChoices):
    START = 'Start'
    SUCCESS = 'Success'
    FAILURE = 'Failure'


class P2P(models.Model):
    # id autoadded
    check_num = models.ForeignKey(Checks, null=False,
                                  on_delete=models.CASCADE,
                                  db_column="Check")
    checkingpeer = models.ForeignKey(Peers, null=False,
                                     on_delete=models.CASCADE,
                                     db_column="checkingpeer")
    state = models.CharField(choices=CheckStatus.choices, db_column="state")
    time = models.TimeField(db_column="time")

    class Meta:
        db_table = "p2p"
        managed = False


class Verter(models.Model):
    # id autoadded
    check_num = models.ForeignKey(Checks, null=False, on_delete=models.CASCADE,
                                  db_column="Check",)
    state = models.CharField(choices=CheckStatus.choices, db_column="state")
    time = models.TimeField(db_column="time")

    class Meta:
        db_table = "verter"
        managed = False


class TransferredPoints(models.Model):
    # id autoadded
    checking = models.ForeignKey(Peers, null=False, on_delete=models.CASCADE,
                                 db_column="checkingpeer")
    checked = models.ForeignKey(Peers, null=False, on_delete=models.CASCADE,
                                related_name="+", db_column="checkedpeer")
    points_amount = models.IntegerField(null=False, default=0,
                                        db_column="pointsamount")

    class Meta:
        db_table = "transferredpoints"
        managed = False
        unique_together = [["checking", "checked"]]


class Friends(models.Model):
    # id autoadded
    peer1 = models.ForeignKey(Peers, null=False, on_delete=models.CASCADE,
                              db_column="peer1")
    peer2 = models.ForeignKey(Peers, null=False, on_delete=models.CASCADE,
                              related_name="+", db_column="peer2")

    class Meta:
        db_table = "friends"
        managed = False
        unique_together = [["peer1", "peer2"]]


class Recommendations(models.Model):
    # id autoadded
    peer = models.ForeignKey(Peers, null=False, on_delete=models.CASCADE,
                             db_column="peer")
    recommended_peer = models.ForeignKey(Peers, null=False,
                                         on_delete=models.CASCADE,
                                         related_name="+",
                                         db_column="recommendedpeer")

    class Meta:
        db_table = "recommendations"
        managed = False
        unique_together = [["peer", "recommended_peer"]]


class XP(models.Model):
    # id autoadded
    check_num = models.ForeignKey(Checks, null=False, on_delete=models.CASCADE,
                                  db_column="Check")
    xp_amount = models.IntegerField(null=False, default=0, db_column="xpamount")

    class Meta:
        db_table = "xp"
        managed = False


class TimeTracking(models.Model):
    # id autoadded
    peer = models.ForeignKey(Peers, null=False, on_delete=models.CASCADE,
                             db_column="peer")
    date = models.DateField(db_column="date")
    time = models.TimeField(db_column="time")
    state = models.SmallIntegerField(choices=[(1, '1'), (2, '2')],
                                     db_column="state")

    class Meta:
        db_table = "timetracking"
        managed = False

