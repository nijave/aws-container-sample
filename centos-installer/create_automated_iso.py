import pycdlib
import io
import logging

logger = logging.getLogger(__name__)
logger.basicConfig(level=logging.INFO)


iso = pycdlib.PyCdlib()
logger.info("Opening ISO")
iso.open('../centos.iso')
logger.info("Checking contents")
logger.info([f.file_identifier() for f in iso.list_children(iso_path='/')])

logger.info("Adding kickstart file (ks.cfg)")
iso.add_fp(open('../ks.cfg', 'rb'), len(open('../ks.cfg', 'rb').read()), '/KS.CFG;1', rr_name='ks.cfg')


def replace_file(path, rr_name, replace_contents):
    out = io.BytesIO()
    iso.get_file_from_iso_fp(out, iso_path=path)
    out.seek(0)
    data = out.read().decode("utf-8")
    for repl in replace_contents:
        data = data.replace(repl[0], repl[1])
    out = io.BytesIO()
    data_length = out.write(data.encode("utf-8"))
    out.seek(0)
    iso.rm_file(path)
    iso.add_fp(out, data_length, path, rr_name=rr_name)


logger.info("Modifying isolinux.cfg (BIOS boot) to use kickstart")
replace_file("/ISOLINUX/ISOLINUX.CFG;1", "isolinux.cfg", [
    ("  menu default\n", ""),
    ("Install CentOS 7\n", "Install CentOS 7\n  menu default\n"),
    ("64 quiet", "64 ks=cdrom:/ks.cfg"),
    ("timeout 600", "timeout 50")
])

logger.info("Modifiying grub.cfg (EFI boot) to use kickstart")
replace_file('/EFI/BOOT/GRUB.CFG;1', "grub.cfg", [
    ('default="1"', 'default="0"'),
    ("64 quiet", "64 ks=cdrom:/ks.cfg"),
    ("timeout=60", "timeout=5"),
])

logger.info("Writing new ISO")
iso.write("centos3.iso")
iso.close()
logger.info("Done")
