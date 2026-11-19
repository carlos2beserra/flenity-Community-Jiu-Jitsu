import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Prisma } from '@prisma/client';
import { CommunityMediaService } from './community-media.service';
import { CommunityMembersService } from './community-members.service';
import { CommunityNotificationsService } from './community-notifications.service';
import { CommunityProfilesService } from './community-profiles.service';
import { CommunityStoriesService } from './community-stories.service';
import {
  asPrisma,
  author,
  createPrismaMock,
  PrismaMock,
  staffAuthor,
  testViews,
  viewer,
} from './community.test-helpers';
import { MediaStorage } from './media-storage';

describe('CommunityMembersService', () => {
  let prisma: PrismaMock;
  let service: CommunityMembersService;

  beforeEach(() => {
    prisma = createPrismaMock();
    service = new CommunityMembersService(asPrisma(prisma));
  });

  it('reuses the profile of an active student with app access', async () => {
    prisma.student.findFirst.mockResolvedValue({ id: 'student-1' });
    prisma.communityMember.findUnique.mockResolvedValue({ id: 'member-1' });

    await expect(service.resolve({ userId: 'student-1', academyId: 'academy-1', role: 'STUDENT' })).resolves.toEqual({
      memberId: 'member-1',
      academyId: 'academy-1',
    });
    expect(prisma.student.findFirst.mock.calls[0][0].where).toMatchObject({
      id: 'student-1',
      academyId: 'academy-1',
      status: 'ACTIVE',
    });
    expect(prisma.communityMember.create).not.toHaveBeenCalled();
  });

  it('creates the staff profile on the first visit', async () => {
    prisma.user.findFirst.mockResolvedValue({ id: 'prof-1' });
    prisma.communityMember.findUnique.mockResolvedValue(null);
    prisma.communityMember.create.mockResolvedValue({ id: 'member-prof' });

    const result = await service.resolve({ userId: 'prof-1', academyId: 'academy-1', role: 'INSTRUCTOR' });

    expect(result.memberId).toBe('member-prof');
    expect(prisma.communityMember.create).toHaveBeenCalledWith({
      data: { academyId: 'academy-1', userId: 'prof-1' },
      select: { id: true },
    });
  });

  it('recovers when a parallel request created the profile first', async () => {
    prisma.user.findFirst.mockResolvedValue({ id: 'prof-1' });
    prisma.communityMember.findUnique.mockResolvedValue(null);
    prisma.communityMember.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('unique', { code: 'P2002', clientVersion: 'test' }),
    );
    prisma.communityMember.findUniqueOrThrow.mockResolvedValue({ id: 'member-prof' });

    await expect(service.resolve({ userId: 'prof-1', academyId: 'academy-1', role: 'ADMIN' })).resolves.toMatchObject({
      memberId: 'member-prof',
    });
  });

  it('blocks students without access and staff from another academy', async () => {
    prisma.student.findFirst.mockResolvedValue(null);
    await expect(service.resolve({ userId: 's', academyId: 'academy-1', role: 'STUDENT' })).rejects.toBeInstanceOf(
      ForbiddenException,
    );

    prisma.user.findFirst.mockResolvedValue(null);
    await expect(service.resolve({ userId: 'u', academyId: 'other', role: 'INSTRUCTOR' })).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(prisma.user.findFirst.mock.calls[0][0].where).toEqual({ id: 'u', academyId: 'other' });
  });
});

describe('CommunityProfilesService', () => {
  let prisma: PrismaMock;
  let notifications: { notify: jest.Mock; retract: jest.Mock };
  let media: { claimable: jest.Mock; discard: jest.Mock };
  let service: CommunityProfilesService;
  const me = viewer();

  beforeEach(() => {
    prisma = createPrismaMock();
    notifications = { notify: jest.fn(), retract: jest.fn() };
    media = { claimable: jest.fn(), discard: jest.fn() };
    service = new CommunityProfilesService(
      asPrisma(prisma),
      testViews(),
      media as unknown as CommunityMediaService,
      notifications as unknown as CommunityNotificationsService,
    );
  });

  const profileRow = (row: Record<string, unknown>) => ({
    bio: null,
    academy: { name: 'Academia Centro' },
    _count: { posts: 0, followers: 0, following: 0 },
    ...row,
  });

  it('follows and unfollows a member of the same academy', async () => {
    prisma.communityMember.findFirst.mockResolvedValue({ id: 'other' });
    prisma.communityFollow.findUnique.mockResolvedValueOnce(null).mockResolvedValueOnce({ followerId: 'me' });

    await expect(service.toggleFollow(me, 'other')).resolves.toEqual({ following: true });
    expect(prisma.communityFollow.create).toHaveBeenCalledWith({ data: { followerId: 'me', followingId: 'other' } });
    expect(notifications.notify).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'FOLLOW', actorId: 'me', recipientId: 'other' }),
    );

    await expect(service.toggleFollow(me, 'other')).resolves.toEqual({ following: false });
    expect(notifications.retract).toHaveBeenCalledWith(expect.objectContaining({ type: 'FOLLOW' }));
  });

  it('cannot follow yourself or someone outside the academy', async () => {
    await expect(service.toggleFollow(me, 'me')).rejects.toBeInstanceOf(BadRequestException);

    prisma.communityMember.findFirst.mockResolvedValue(null);
    await expect(service.toggleFollow(me, 'stranger')).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.communityMember.findFirst.mock.calls[0][0].where).toMatchObject({ academyId: 'academy-1', id: 'stranger' });
  });

  it('returns counts, belt and follow state on a student profile', async () => {
    prisma.communityMember.findFirst.mockResolvedValue(
      profileRow({
        ...author('other', 'Bruno Lima'),
        bio: 'Faixa azul',
        student: { name: 'Bruno Lima', ranks: [{ degree: 2, belt: { name: 'Azul', color: '#1e5bd6' } }] },
        _count: { posts: 3, followers: 10, following: 4 },
      }),
    );
    prisma.communityFollow.findUnique.mockResolvedValueOnce({ followerId: 'me' }).mockResolvedValueOnce(null);

    await expect(service.profile(me, 'other')).resolves.toMatchObject({
      handle: 'bruno.lima',
      bio: 'Faixa azul',
      belt: { name: 'Azul', degree: 2 },
      counts: { posts: 3, followers: 10, following: 4 },
      isStaff: false,
      isMe: false,
      isFollowing: true,
      followsMe: false,
    });
  });

  it('shows a professor profile with role label and no belt', async () => {
    prisma.communityMember.findFirst.mockResolvedValue(profileRow({ ...staffAuthor('prof-1') }));
    prisma.communityFollow.findUnique.mockResolvedValue(null);

    await expect(service.profile(me, 'prof-1')).resolves.toMatchObject({
      name: 'Mestre Carlos',
      isStaff: true,
      roleLabel: 'Professor',
      belt: null,
    });
  });

  it('searches students and staff by name', async () => {
    prisma.communityMember.findMany.mockResolvedValue([staffAuthor('prof-1')]);
    prisma.communityMember.count.mockResolvedValue(1);
    prisma.communityFollow.findMany.mockResolvedValue([]);

    const page = await service.search(me, { page: 1, pageSize: 20, search: 'carlos' });

    expect(page.items[0]).toMatchObject({ id: 'prof-1', roleLabel: 'Professor', isFollowing: false });
    const where = prisma.communityMember.findMany.mock.calls[0][0].where;
    expect(JSON.stringify(where)).toContain('"user":{"is":{"name":{"contains":"carlos"');
    expect(JSON.stringify(where)).toContain('"student":{"is":{"name":{"contains":"carlos"');
  });

  it('replaces the avatar with an image and discards the previous one', async () => {
    prisma.communityMember.findUniqueOrThrow.mockResolvedValue({ avatarMediaId: 'old' });
    media.claimable.mockResolvedValue([{ id: 'new', kind: 'IMAGE' }]);
    prisma.communityMember.findFirst.mockResolvedValue(profileRow({ ...author('me'), student: { name: 'Ana', ranks: [] } }));

    await service.updateProfile(me, { avatarMediaId: 'new', bio: 'Oss' });

    expect(prisma.communityMember.update).toHaveBeenCalledWith({
      where: { id: 'me' },
      data: { bio: 'Oss', avatarMedia: { connect: { id: 'new' } } },
    });
    expect(media.discard).toHaveBeenCalledWith(['old']);
  });

  it('refuses a video as avatar', async () => {
    prisma.communityMember.findUniqueOrThrow.mockResolvedValue({ avatarMediaId: null });
    media.claimable.mockResolvedValue([{ id: 'vid', kind: 'VIDEO' }]);

    await expect(service.updateProfile(me, { avatarMediaId: 'vid' })).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.communityMember.update).not.toHaveBeenCalled();
  });
});

describe('CommunityStoriesService', () => {
  let prisma: PrismaMock;
  let media: { claimable: jest.Mock; discard: jest.Mock };
  let service: CommunityStoriesService;
  const me = viewer();

  beforeEach(() => {
    prisma = createPrismaMock();
    media = { claimable: jest.fn(), discard: jest.fn() };
    service = new CommunityStoriesService(asPrisma(prisma), testViews(), media as unknown as CommunityMediaService);
  });

  const story = (id: string, memberId: string, seen: boolean) => ({
    id,
    memberId,
    caption: null,
    createdAt: new Date(),
    expiresAt: new Date(Date.now() + 3_600_000),
    author: author(memberId, memberId),
    media: { id: `m-${id}`, kind: 'IMAGE' },
    views: seen ? [{ memberId: 'me' }] : [],
  });

  it('groups active flashes by author with mine first and unseen before seen', async () => {
    prisma.communityStory.findMany.mockResolvedValue([
      story('s1', 'seen-author', true),
      story('s2', 'fresh-author', false),
      story('s3', 'me', false),
    ]);

    const tray = await service.tray(me);

    expect(tray.map((group) => group.author.id)).toEqual(['me', 'fresh-author', 'seen-author']);
    expect(tray[0].hasUnseen).toBe(false);
    expect(tray[1].hasUnseen).toBe(true);
    expect(prisma.communityStory.findMany.mock.calls[0][0].where.expiresAt.gt).toBeInstanceOf(Date);
  });

  it('creates a flash that expires in 24 hours', async () => {
    media.claimable.mockResolvedValue([{ id: 'm1', kind: 'IMAGE' }]);
    prisma.communityStory.create.mockImplementation(({ data }) => ({ id: 'st1', ...data, media: { id: 'm1', kind: 'IMAGE' } }));

    const created = await service.create(me, { mediaId: 'm1', caption: 'Treino' });

    const { createdAt, expiresAt, memberId } = prisma.communityStory.create.mock.calls[0][0].data;
    expect(memberId).toBe('me');
    expect(expiresAt.getTime() - createdAt.getTime()).toBe(24 * 3_600_000);
    expect(created).toMatchObject({ id: 'st1', caption: 'Treino', seen: true });
  });

  it('only the author can list viewers or delete a flash', async () => {
    prisma.communityStory.findFirst.mockResolvedValue({ memberId: 'someone', mediaId: 'm1' });

    await expect(service.viewers(me, 'st1')).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.remove(me, 'st1')).rejects.toBeInstanceOf(ForbiddenException);
    expect(media.discard).not.toHaveBeenCalled();
  });

  it('does not record a view of my own flash', async () => {
    prisma.communityStory.findFirst.mockResolvedValue({ memberId: 'me' });

    await service.markViewed(me, 'st1');

    expect(prisma.communityStoryView.upsert).not.toHaveBeenCalled();
  });
});

describe('CommunityNotificationsService', () => {
  it('never notifies the actor about their own action', async () => {
    const prisma = createPrismaMock();
    const service = new CommunityNotificationsService(asPrisma(prisma), testViews());

    await service.notify({ academyId: 'a', actorId: 'me', recipientId: 'me', type: 'LIKE', postId: 'p' });
    expect(prisma.communityNotification.create).not.toHaveBeenCalled();

    await service.notify({ academyId: 'a', actorId: 'me', recipientId: 'you', type: 'LIKE', postId: 'p' });
    expect(prisma.communityNotification.create).toHaveBeenCalledWith({
      data: { academyId: 'a', actorId: 'me', recipientId: 'you', type: 'LIKE', postId: 'p' },
    });
  });
});

describe('CommunityMediaService', () => {
  let prisma: PrismaMock;
  let storage: { save: jest.Mock; remove: jest.Mock; pathFor: jest.Mock };
  let service: CommunityMediaService;
  const me = viewer();

  beforeEach(() => {
    prisma = createPrismaMock();
    storage = { save: jest.fn().mockResolvedValue('key.jpg'), remove: jest.fn(), pathFor: jest.fn() };
    service = new CommunityMediaService(asPrisma(prisma), storage as unknown as MediaStorage, testViews());
  });

  it('rejects files whose bytes are not a supported image or video', async () => {
    const fake = Buffer.from('<?php echo 1; ?>');
    await expect(service.upload(me, { buffer: fake, size: fake.length })).rejects.toBeInstanceOf(BadRequestException);
    expect(storage.save).not.toHaveBeenCalled();
  });

  it('stores a JPEG for the profile and removes the file if the database write fails', async () => {
    const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(32)]);
    prisma.communityMedia.create.mockRejectedValue(new Error('db down'));

    await expect(service.upload(me, { buffer: jpeg, size: jpeg.length })).rejects.toThrow('db down');
    expect(prisma.communityMedia.create.mock.calls[0][0].data).toMatchObject({ ownerId: 'me', academyId: 'academy-1' });
    expect(storage.save).toHaveBeenCalledWith(jpeg, 'jpg');
    expect(storage.remove).toHaveBeenCalledWith(['key.jpg']);
  });

  it('refuses media owned by someone else or already used', async () => {
    prisma.communityMedia.findMany.mockResolvedValue([{ id: 'm1', kind: 'IMAGE' }]);

    await expect(service.claimable(me, ['m1', 'm2'])).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.communityMedia.findMany.mock.calls[0][0].where).toMatchObject({
      ownerId: 'me',
      academyId: 'academy-1',
      postMedia: { is: null },
    });
    await expect(service.claimable(me, ['m1', 'm1'])).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('MediaStorage', () => {
  it('never resolves paths outside the media directory', () => {
    const config = { get: () => '/tmp/flenity-media-test' } as unknown as ConfigService;
    const storage = new MediaStorage(config);

    expect(() => storage.pathFor('../../etc/passwd')).toThrow('Chave de mídia inválida');
    expect(() => storage.pathFor('0b7a3c1e-1d2f-4a5b-8c9d-0e1f2a3b4c5d.exe')).toThrow();
    expect(storage.pathFor('0b7a3c1e-1d2f-4a5b-8c9d-0e1f2a3b4c5d.jpg')).toBe(
      '/tmp/flenity-media-test/0b7a3c1e-1d2f-4a5b-8c9d-0e1f2a3b4c5d.jpg',
    );
  });
});
